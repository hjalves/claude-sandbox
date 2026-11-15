# Disposable Arch Linux VM for running Claude Code with all permission checks off.
#
#   vagrant up                    create and provision (first run ~5 min)
#   vagrant ssh -c claude-yolo    start Claude Code in ~/workspace, no prompts
#   vagrant snapshot restore clean    roll back to the freshly provisioned state
#   vagrant destroy -f            throw the whole VM away
#
# The VM is the safety boundary: nothing from the Mac is shared into it by
# default, so Claude can only touch what you put inside the VM. It does get a
# bridged network card on your LAN (see BRIDGE_IF below).

require_relative "../vagrant/lib/port_check_fix"

# Host interface for the bridged network card, which gives the VM its own
# address on your LAN (from your router's DHCP). en0 is the Wi-Fi on a MacBook;
# use en3/en4 etc. for a USB or Thunderbolt Ethernet adapter. Set BRIDGE_IF=""
# to remove the card and keep the VM behind the Mac's NAT only. Takes effect
# on the next `vagrant up` / `vagrant reload`.
BRIDGE_IF = ENV.fetch("BRIDGE_IF", "en0")

Vagrant.configure("2") do |config|
  config.vm.box = "local/arch"
  config.vm.hostname = "claude-sandbox"

  # No host folders are shared by default. Sharing one gives the unrestricted
  # agent write access to it; uncomment only for a folder you're happy to lose.
  config.vm.synced_folder ".", "/vagrant", disabled: true
  # config.vm.synced_folder "~/Projects/some-repo", "/home/vagrant/workspace/some-repo"

  # Pin the SSH forward to 127.0.0.1 (where QEMU binds it) so Vagrant's port
  # collision check tests that address and two VMs never get the same port.
  config.vm.network "forwarded_port", id: "ssh", guest: 22, host: 2222,
    host_ip: "127.0.0.1", auto_correct: true

  config.vm.provider "utm" do |u|
    u.name   = "claude-sandbox"
    u.cpus   = 4
    u.memory = 6144
    u.icon   = "arch-linux"
    u.notes  = "Claude Code sandbox (ClaudeArch/claude-sandbox). Disposable."

    # vagrant_utm ignores `public_network` and can't add network cards, but a
    # pre-boot customization can run our own script (an absolute path is used
    # as is). It adds the bridged card as the 3rd card, after the Shared and
    # Emulated VLAN cards Vagrant relies on, and is a no-op once it's there.
    u.customize "pre-boot",
      [File.expand_path("scripts/bridged-nic.applescript", __dir__), :id, BRIDGE_IF]
  end

  config.vm.provision "system", type: "shell", path: "provision/system.sh"
  config.vm.provision "claude", type: "shell", path: "provision/claude.sh", privileged: false
end
