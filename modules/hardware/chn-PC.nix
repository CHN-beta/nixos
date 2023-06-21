{ pkgs, ... }@inputs:
{
	config =
	{
		nix.settings.system-features = [ "gccarch-alderlake" ];
		services.dbus.implementation = "broker";
		programs.dconf.enable = true;
		hardware.opengl.enable = true;
		systemd.services =
		{
			reload-iwlwifi-after-hibernate =
			{
				description = "reload iwlwifi after resume from hibernate";
				after = [ "systemd-hibernate.service" ];
				serviceConfig =
				{
					Type = "oneshot";
					ExecStart =
					[
						"${pkgs.kmod}/bin/modprobe -r iwlwifi"
						"${pkgs.kmod}/bin/modprobe iwlwifi"
						"${pkgs.bash}/bin/bash -c '<<< 0 > /sys/devices/system/cpu/intel_pstate/no_turbo'"
					];
				};
				wantedBy = [ "systemd-hibernate.service" ];
			};
			lid-no-wakeup =
			{
				description = "lid no wake up";
				serviceConfig.ExecStart = "${pkgs.bash}/bin/bash -c '<<< LID0 > /proc/acpi/wakeup'";
				wantedBy = [ "multi-user.target" ];
			};
		};
	};
}
