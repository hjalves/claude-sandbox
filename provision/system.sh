#!/bin/bash
# System packages for a Claude Code workstation. Runs as root.
set -euo pipefail

# Resolve through systemd-resolved's local stub (127.0.0.53), which follows the
# DNS servers and search domains each network card gets from DHCP.
echo "==> Pointing /etc/resolv.conf at systemd-resolved"
systemctl enable --now systemd-resolved
ln -sfn /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
for _ in {1..30}; do getent hosts archlinux.org >/dev/null && break; sleep 1; done

echo "==> Updating the system"
pacman -Syu --noconfirm

echo "==> Installing development tools"
pacman -S --noconfirm --needed \
  base-devel git github-cli openssh inetutils which less man-db \
  curl wget unzip zip tar rsync \
  ripgrep fd jq tree htop tmux vim nano \
  python python-pip uv nodejs npm \
  sqlite

# Give the agent a little headroom: the box's 16 GB disk is small for big repos,
# and a swap file stops the OOM killer ending long builds on 6 GB of RAM.
if [[ ! -f /swapfile ]]; then
  echo "==> Adding a 2 GB swap file"
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap -q /swapfile
  echo '/swapfile none swap defaults 0 0' >> /etc/fstab
  swapon /swapfile
fi

# The bridged network card puts sshd on your LAN, and the box's vagrant user has
# the well-known password "vagrant" plus passwordless sudo. Vagrant only needs
# key login, so turn passwords off. sshd keeps the first value it reads, so
# this file must sort before Arch's 99-archlinux.conf.
echo "==> Disabling SSH password login"
cat > /etc/ssh/sshd_config.d/10-no-password.conf <<'EOF'
# Key-only SSH (claude-sandbox provisioning): the VM is reachable from the LAN.
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
EOF
sshd -t
systemctl reload sshd

pacman -Scc --noconfirm >/dev/null
echo "==> System ready"
