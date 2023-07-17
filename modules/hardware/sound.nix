inputs:
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
		environment.etc."wireplumber/main.lua.d/50-alsa-config.lua".text =
			let
				content = builtins.readFile
					("/." + inputs.pkgs.wireplumber + "/share/wireplumber/main.lua.d/50-alsa-config.lua");
				matched = builtins.match ".*\n([[:space:]]*)(--\\[\"session\\.suspend-timeout-seconds\"][^\n]*)[\n].*" content;
				spaces = builtins.elemAt matched 0;
				comment = builtins.elemAt matched 1;
				config = "[\"session.suspend-timeout-seconds\"] = 0";
			in
				builtins.replaceStrings [(spaces + comment)] [(spaces + config)] content;
	};
}
