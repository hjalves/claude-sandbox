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

git config --global init.defaultBranch main
git config --global user.name  >/dev/null || git config --global user.name  "Claude Sandbox"
git config --global user.email >/dev/null || git config --global user.email "claude-sandbox@localhost"

echo "==> $(claude --version)"
echo "Log in once with:  vagrant ssh -c claude-yolo   (or set ANTHROPIC_API_KEY in the VM)"
