{ pkgs, ... }@inputs:
{
	config =
	{
		sound.enable = true;
		hardware.pulseaudio.enable = false;
		security.rtkit.enable = true;
		services.pipewire =
		{
			enable = true;
			alsa = { enable = true; support32Bit = true; };
			pulse.enable = true;
		};
		systemd.user.services.pipewire.serviceConfig.Nice = -20;
		systemd.user.services.pipewire-pulse.serviceConfig.Nice = -20;
		systemd.services.rtkit-daemon.serviceConfig.ExecStart =
		[
			""
			"${inputs.pkgs.rtkit.outPath}/libexec/rtkit-daemon --our-realtime-priority=90 --max-realtime-priority=89 --min-nice-level=-19 --scheduling-policy=RR --rttime-usec-max=2000000 --users-max=100 --processes-per-user-max=1000 --threads-per-user-max=10000 --actions-burst-sec=10 --actions-per-burst-max=1000 --canary-cheep-msec=30000 --canary-watchdog-msec=60000"
		];
	};
}
