#!/bin/bash
# Installs Claude Code for the vagrant user and configures it to run without
# permission prompts. Runs as vagrant (not root: bypass mode refuses root).
set -euo pipefail

echo "==> Installing Claude Code (native installer)"
if [[ ! -x "$HOME/.local/bin/claude" ]]; then
  curl -fsSL https://claude.ai/install.sh | bash
fi

# Put ~/.local/bin on PATH at the very top of .bashrc: Arch's default .bashrc
# returns early for non-interactive shells (e.g. `vagrant ssh -c`), so a line
# appended at the end never runs there.
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
touch "$HOME/.bashrc"
sed -i '\|^export PATH="$HOME/.local/bin:$PATH"$|d' "$HOME/.bashrc"
sed -i "1i $PATH_LINE" "$HOME/.bashrc"
export PATH="$HOME/.local/bin:$PATH"

echo "==> Updating ~/.claude/settings.json (bypassPermissions, Remote Control at startup)"
# Merge into any existing file so choices made inside Claude Code (theme,
# model, ...) survive re-provisioning.
#  - bypassPermissions + skipDangerousModePermissionPrompt: no permission prompts
#  - remoteControlAtStartup: every interactive session registers with Remote
#    Control, so it shows up in claude.ai/code and the Claude app (needs a
#    claude.ai login; API keys can't use Remote Control)
SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$HOME/.claude"
[[ -s "$SETTINGS" ]] && jq -e . "$SETTINGS" >/dev/null 2>&1 || echo '{}' > "$SETTINGS"
jq '. * {
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": {"defaultMode": "bypassPermissions"},
  "skipDangerousModePermissionPrompt": true,
  "remoteControlAtStartup": true
}' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"

mkdir -p "$HOME/workspace"
cat > "$HOME/workspace/CLAUDE.md" <<'EOF'
# Sandbox

You are running in a disposable Arch Linux ARM VM (UTM, managed by Vagrant)
with all permission checks off. You have passwordless sudo and can install
anything with `sudo pacman -S <pkg>`. Nothing on this machine is precious, but
the network is real: don't attack other hosts or leak credentials.
EOF

# Convenience launcher: start Claude Code in the workspace with no prompts.
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/claude-yolo" <<'EOF'
#!/bin/bash
cd "$HOME/workspace" && exec "$HOME/.local/bin/claude" --dangerously-skip-permissions "$@"
EOF
chmod +x "$HOME/.local/bin/claude-yolo"

# Arch's .bashrc returns early for non-interactive shells, so `vagrant ssh -c`
# never sees ~/.local/bin. Link both commands somewhere on the system PATH.
sudo ln -sf "$HOME/.local/bin/claude"      /usr/local/bin/claude
sudo ln -sf "$HOME/.local/bin/claude-yolo" /usr/local/bin/claude-yolo
sudo ln -sf "$HOME/.local/bin/claude-rc"   /usr/local/bin/claude-rc

echo "==> Installing the Remote Control server service"
# `claude remote-control` (server mode) registers this VM as an environment in
# claude.ai/code and the Claude app, where you can start new sessions on it.
# A systemd user service runs it at boot inside a dedicated tmux socket, so
# `claude-rc` can attach to see its status/QR code (detach with Ctrl-b d).
cat > "$HOME/.local/bin/claude-rc-server" <<'EOF'
#!/bin/bash
# Run by claude-remote-control.service inside tmux. Waits for the network and
# a claude.ai login (none after `vagrant snapshot restore clean`), then serves.
cd "$HOME/workspace"
until getent hosts claude.ai >/dev/null; do sleep 2; done
until claude auth status 2>/dev/null | grep -q '"loggedIn": true'; do
  echo "Not logged in to Claude. Run claude-yolo once to log in; retrying in 60s."
  sleep 60
done
exec claude remote-control --spawn same-dir --permission-mode bypassPermissions \
  --remote-control-session-name-prefix "$(hostname)"
EOF
cat > "$HOME/.local/bin/claude-rc" <<'EOF'
#!/bin/bash
# Show the Remote Control server (URL, QR code with space). Detach: Ctrl-b d.
exec tmux -L claude-rc attach -t claude-rc
EOF
chmod +x "$HOME/.local/bin/claude-rc-server" "$HOME/.local/bin/claude-rc"

mkdir -p "$HOME/.config/systemd/user"
cat > "$HOME/.config/systemd/user/claude-remote-control.service" <<'EOF'
[Unit]
Description=Claude Code Remote Control server (tmux -L claude-rc)

[Service]
Type=forking
ExecStart=/usr/bin/tmux -L claude-rc new-session -d -s claude-rc -x 160 -y 45 %h/.local/bin/claude-rc-server
ExecStop=/usr/bin/tmux -L claude-rc kill-server
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
EOF
# Linger starts the user's systemd instance (and this service) at boot,
# without anyone logging in.
sudo loginctl enable-linger "$USER"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
systemctl --user daemon-reload
systemctl --user enable --now claude-remote-control.service

git config --global init.defaultBranch main
git config --global user.name  >/dev/null || git config --global user.name  "Claude Sandbox"
git config --global user.email >/dev/null || git config --global user.email "claude-sandbox@localhost"

echo "==> $(claude --version)"
echo "Log in once with:  vagrant ssh -c claude-yolo   (or set ANTHROPIC_API_KEY in the VM)"
