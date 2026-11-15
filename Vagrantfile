# Disposable Arch Linux VM for running Claude Code with all permission checks off.
#
#   vagrant up                    create and provision (first run ~5 min)
#   vagrant ssh -c claude-yolo    start Claude Code in ~/workspace, no prompts
#   vagrant snapshot restore clean    roll back to the freshly provisioned state
#   vagrant destroy -f            throw the whole VM away
#
# The VM is the safety boundary: nothing from the Mac is shared into it by
# default, so Claude can only touch what you put inside the VM.

require_relative "../vagrant/lib/port_check_fix"

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
  end

  config.vm.provision "system", type: "shell", path: "provision/system.sh"
  config.vm.provision "claude", type: "shell", path: "provision/claude.sh", privileged: false
end
