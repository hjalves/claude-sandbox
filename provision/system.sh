#!/bin/bash
# System packages for a Claude Code workstation. Runs as root.
set -euo pipefail

# Resolve through systemd-resolved's local stub (127.0.0.53), which follows the
# DNS servers and search domains each network card gets from DHCP.
echo "==> Pointing /etc/resolv.conf at systemd-resolved"
systemctl enable --now systemd-resolved
ln -sfn /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
for _ in {1..30}; do getent hosts archlinux.org >/dev/null && break; sleep 1; done

# mDNS through systemd-resolved: the VM answers as <hostname>.local (so the Mac
# and the LAN can reach it by name) and resolves other .local names. It needs
# both the global switch and the per-link one in networkd. enp0s2 is QEMU's
# user-mode card (10.0.2.15, only for the SSH port forward); nothing outside
# the VM can reach that address, so keep it out of mDNS answers. networkd uses
# the first .network file that matches, so 10-qemu-user.network wins for it.
echo "==> Enabling mDNS (systemd-resolved)"
install -d /etc/systemd/resolved.conf.d /etc/systemd/network/20-ethernet.network.d
printf '[Resolve]\nMulticastDNS=yes\n' > /etc/systemd/resolved.conf.d/mdns.conf
printf '[Network]\nMulticastDNS=yes\n' > /etc/systemd/network/20-ethernet.network.d/mdns.conf
printf '[Match]\nName=enp0s2\n\n[Network]\nDHCP=yes\nMulticastDNS=no\n' \
  > /etc/systemd/network/10-qemu-user.network
systemctl restart systemd-resolved
networkctl reload

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

# Under UTM's QEMU with HVF, a reboot started inside the guest hangs: the VM
# resets but the next boot never finishes and QEMU spins every core. It only
# happens with more than one vCPU, so take the secondary vCPUs offline (PSCI
# CPU_OFF) as the very last step before a reboot. systemd-shutdown runs this
# after everything is unmounted, with "reboot", "poweroff", "halt" or "kexec".
echo "==> Installing the reboot workaround (offline secondary vCPUs)"
install -d /usr/lib/systemd/system-shutdown
cat > /usr/lib/systemd/system-shutdown/offline-cpus.sh <<'EOF'
#!/bin/sh
# claude-sandbox provisioning: see provision/system.sh for why.
[ "$1" = reboot ] || exit 0
for c in /sys/devices/system/cpu/cpu[1-9]*/online; do
  [ -w "$c" ] && echo 0 > "$c"
done
exit 0
EOF
chmod 755 /usr/lib/systemd/system-shutdown/offline-cpus.sh

pacman -Scc --noconfirm >/dev/null
echo "==> System ready"
