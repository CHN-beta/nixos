{ pkgs, ... }@inputs:
{
	config =
	{
		nix.settings.system-features = [ "gccarch-alderlake" ];
		services.dbus.implementation = "broker";
		programs.dconf.enable = true;
		hardware.opengl.enable = true;
		systemd.services.reload-iwlwifi-after-hibernate =
		{
			description = "reload iwlwifi after resume from hibernate";
			after = [ "systemd-hibernate.service" ];
			serviceConfig =
			{
				Type = "oneshot";
				ExecStart =
				[
					"${pkgs.kmod}/bin/modprobe -r iwlmvm iwlwifi"
					"${pkgs.kmod}/bin/modprobe iwlwifi"
					"echo 0 | tee /sys/devices/system/cpu/intel_pstate/no_turbo"
				];
			};
			wantedBy = [ "systemd-hibernate.service" ];
		};
	};
}
