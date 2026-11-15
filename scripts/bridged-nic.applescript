-- Ensure a UTM VM has exactly one bridged network card on a given host
-- interface, so the guest gets its own address on the Mac's LAN.
--
-- Usage: osascript bridged-nic.applescript <VM_UUID> <host interface | "">
--   e.g. en0 (Wi-Fi on a MacBook), en3/en4 (USB/Thunderbolt Ethernet).
--   An empty interface removes the bridged card.
--
-- Run by the Vagrantfile as a vagrant_utm "pre-boot" customization, so the VM
-- is stopped and the change applies on this boot. Running it again is a no-op.
-- The Shared (index 0) and Emulated VLAN (index 1) cards Vagrant needs are
-- never touched; the bridged card is added after them.

on run argv
	set vmID to item 1 of argv
	set hostIf to ""
	if (count of argv) > 1 then set hostIf to item 2 of argv

	tell application "UTM"
		set vm to virtual machine id vmID
		set config to configuration of vm
		set kept to {}
		set found to false
		set changed to false

		repeat with nic in (network interfaces of config)
			set nicRec to contents of nic
			if mode of nicRec is bridged then
				if hostIf is "" or found then
					set changed to true -- drop it (disabled, or a duplicate)
				else
					set found to true
					if host interface of nicRec is not hostIf then
						set host interface of nicRec to hostIf
						set changed to true
					end if
					set end of kept to nicRec
				end if
			else
				set end of kept to nicRec
			end if
		end repeat

		if hostIf is not "" and not found then
			set end of kept to {mode:bridged, host interface:hostIf}
			set changed to true
		end if

		if changed then
			set network interfaces of config to kept
			update configuration of vm with config
			if hostIf is "" then
				return "bridged network card removed"
			else
				return "bridged network card on " & hostIf
			end if
		else
			return "bridged network card already on " & hostIf
		end if
	end tell
end run
