{ pkgs, ... }@inputs:
{
	config =
	{
		sound =
		{
			enable = true;
			extraConfig = "session.suspend-timeout-seconds 0";
		};
		hardware.pulseaudio.enable = false;
		security.rtkit.enable = true;
		services.pipewire =
		{
			enable = true;
			alsa = { enable = true; support32Bit = true; };
			pulse.enable = true;
		};
	};
}
