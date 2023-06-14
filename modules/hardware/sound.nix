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
		systemd.user.services.pipewire.serviceConfig.CPUSchedulingPolicy = -11;
		systemd.user.services.pipewire-pulse.serviceConfig.CPUSchedulingPolicy = -11;
	};
}
