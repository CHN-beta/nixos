# TODO: disable auto usb redirection
inputs:
{
	config =
	{
		virtualisation =
		{
			libvirtd = { enable = true; qemu.runAsRoot = false; onBoot = "ignore"; onShutdown = "shutdown"; };
			spiceUSBRedirection.enable = true;
		};
		environment.systemPackages = with inputs.pkgs; [ qemu_full virt-manager win-spice ];
		systemd.services =
			let
				virsh = "${inputs.pkgs.libvirt}/bin/virsh";
				hibernate = inputs.pkgs.writeShellScript "libvirt-hibernate"
				''
					if [ "$(LANG=C ${virsh} domstate $1)" = 'running' ]
					then
						if ${virsh} dompmsuspend "$1" disk
						then
							echo "Waiting for $1 to suspend"
							while ! [ "$(LANG=C ${virsh} domstate $1)" = 'shut off' ]
							do
								sleep 1
							done
							echo "$1 suspended"
							touch "/tmp/libvirt.$1.suspended"
						else
							echo "Failed to suspend $1"
						fi
					fi
				'';
				resume = inputs.pkgs.writeShellScript "libvirt-resume"
				''
					if [ "$(LANG=C ${virsh} domstate $1)" = 'shut off' ] && [ -f "/tmp/libvirt.$1.suspended" ]
					then
						if ${virsh} start "$1"
						then
							echo "Waiting for $1 to resume"
							while ! [ "$(LANG=C ${virsh} domstate $1)" = 'running' ]
							do
								sleep 1
							done
							echo "$1 resumed"
							rm "/tmp/libvirt.$1.suspended"
						else
							echo "Failed to resume $1"
						fi
					fi
				'';
				makeServices = machine:
				{
					"libvirt-hibernate-${machine}" =
					{
						description = "libvirt hibernate ${machine}";
						wantedBy = [ "systemd-hibernate.service" "systemd-suspend.service" ];
						before = [ "systemd-hibernate.service" "systemd-suspend.service" ];
						serviceConfig = { Type = "oneshot"; ExecStart = "${hibernate} ${machine}"; };
					};
					"libvirt-resume-${machine}" =
					{
						description = "libvirt resume ${machine}";
						wantedBy = [ "systemd-hibernate.service" "systemd-suspend.service" ];
						after = [ "systemd-hibernate.service" "systemd-suspend.service" ];
						serviceConfig = { Type = "oneshot"; ExecStart = "${resume} ${machine}"; };
					};
				};
			in
				(makeServices "win10") // (makeServices "hardconnect");
	};
}
