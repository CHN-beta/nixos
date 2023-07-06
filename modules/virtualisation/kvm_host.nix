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
					if [ "$(LANG=C ${virsh} domstate "$1")" = 'running' ]
					then
						if ${virsh} dompmsuspend "$1" disk
						then
							echo "Waiting for $1 to suspend"
							while ! [ "$(LANG=C ${virsh} domstate "$1")" = 'shut off' ]
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
					if [ "$(LANG=C ${virsh} domstate "$1")" = 'shut off' ] && [ -f "/tmp/libvirt.$1.suspended" ]
					then
						if virsh start "$1"
						then
							echo "Waiting for $1 to resume"
							while ! [ "$(LANG=C ${virsh} domstate "$1")" = 'running' ]
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
			in
			{
				"libvirt-hibernate@" =
				{
					description = "libvirt hibernate";
					before = [ "systemd-hibernate.service" "systemd-suspend.service" ];
					serviceConfig = { Type = "oneshot"; ExecStart = "${hibernate} %i"; };
				};
				"libvirt-resume@" =
				{
					description = "libvirt resume";
					after = [ "systemd-hibernate.service" "systemd-suspend.service" ];
					serviceConfig = { Type = "oneshot"; ExecStart = "${resume} %i"; };
				};
				"libvirt-hibernate@win10" =
				{
					wantedBy = [ "systemd-hibernate.service" "systemd-suspend.service" ];
					overrideStrategy = "asDropin";
				};
				"libvirt-resume@win10" =
				{
					wantedBy = [ "systemd-hibernate.service" "systemd-suspend.service" ];
					overrideStrategy = "asDropin";
				};
				"libvirt-hibernate@hardconnect" =
				{
					wantedBy = [ "systemd-hibernate.service" "systemd-suspend.service" ];
					overrideStrategy = "asDropin";
				};
				"libvirt-resume@hardconnect" =
				{
					wantedBy = [ "systemd-hibernate.service" "systemd-suspend.service" ];
					overrideStrategy = "asDropin";
				};
			};
	};
}
