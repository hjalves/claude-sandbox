#!/bin/bash
# System packages for a Claude Code workstation. Runs as root.
set -euo pipefail

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

pacman -Scc --noconfirm >/dev/null
echo "==> System ready"
