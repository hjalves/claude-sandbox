# Claude Code sandbox VM

A disposable Arch Linux ARM VM (UTM + Vagrant, from the `local/arch` box in `../vagrant`)
where Claude Code runs with **every permission check off**. The VM is the safety boundary.

## Use

```bash
vagrant up              # first run creates and provisions the VM (~5 min)
vagrant ssh             # then, inside:
claude-yolo             # Claude Code in ~/workspace, no permission prompts
```

The first time, `claude-yolo` asks you to log in. It shows a URL: open it on the Mac, sign
in, and paste the code back. To use an API key instead, run `export ANTHROPIC_API_KEY=...`
inside the VM before `claude-yolo`. The login is saved in the VM, so it's lost on
`vagrant destroy` or when you restore a snapshot taken before you logged in.

**Remote Control** works in two ways. Both need a claude.ai login on a Pro, Max, Ultra,
Team or Enterprise plan; API-key logins don't get Remote Control.

- **The VM as a machine**: a systemd user service (`claude-remote-control`, started at boot
  through linger) runs `claude remote-control` in server mode. The VM then shows up in
  claude.ai/code and the Claude app as an environment (`workspace`, sessions named
  `claude-sandbox-…`) where you can start new sessions, up to 32 at once, in `~/workspace`
  with permissions bypassed. Nothing needs to be open on the Mac; the VM just has to be
  running. Inside the VM, `claude-rc` shows the server's URL and QR code (detach with
  Ctrl-b d), and `systemctl --user status claude-remote-control` shows the service. After a
  restore to `clean`, the service waits until you log in again with `claude-yolo`. The first
  run on a new login also asks a one-time "Enable Remote Control? (y/n)" in `claude-rc`.
- **Terminal sessions**: each `claude-yolo` session also shows `/rc active` and appears in
  the session list, so you can continue it from your phone or browser while it runs.

| Command | What it does |
|---|---|
| `vagrant snapshot restore clean` | Roll back to the freshly provisioned VM (taken before login) |
| `vagrant snapshot save <name>` | Save the current state, e.g. after logging in |
| `vagrant halt` / `vagrant up` | Stop / start |
| `vagrant destroy -f` | Delete the VM entirely |

## What's inside

- **VM**: 4 CPUs, 6 GB RAM, 2 GB swap, 16 GB disk (about 10 GB free after provisioning)
- **Tools**: git, gh, ripgrep, fd, jq, Python with pip and uv, Node and npm, base-devel
  (gcc, make), tmux and vim. `vagrant` has passwordless sudo, so Claude can
  `sudo pacman -S` anything else.
- **Claude Code**: native install in `~/.local/bin`, auto-updating. `~/.claude/settings.json`
  sets `permissions.defaultMode: "bypassPermissions"`,
  `skipDangerousModePermissionPrompt: true` and `remoteControlAtStartup: true`. Provisioning
  merges these into the existing file, so your own changes (theme, model) survive
  `vagrant provision`. `claude-yolo` also passes
  `--dangerously-skip-permissions`, and `~/workspace/CLAUDE.md` tells Claude where it is.

## What the sandbox does and doesn't isolate

- **Isolated**: your Mac's files. No folders are shared by default (see the commented
  `synced_folder` line in the `Vagrantfile`). If you share one, Claude can change or delete
  anything in it.
- **Not isolated**: the network. The VM has full internet access, can reach your LAN, and can
  reach services on your Mac at `192.168.64.1`. Anything you log into inside the VM (Claude,
  `gh auth login`, git credentials) can be used by the agent.

To work on a repository, clone it inside the VM (`git clone` in `~/workspace`) and push
from there, or copy files out with `vagrant ssh -c 'cat ...'` or `scp -P 2250`.
