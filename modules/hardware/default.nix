inputs:
{
	options.nixos.hardware = let inherit (inputs.lib) mkOption types; in
	{
		bluetooth.enable = mkOption { type = types.bool; default = false; };
		joystick.enable = mkOption { type = types.bool; default = false; };
		printer.enable = mkOption { type = types.bool; default = false; };
		sound.enable = mkOption { type = types.bool; default = false; };
	};
	config =
	{
		hardware = {}
			// (if inputs.config.nixos.hardware.bluetooth.enable then { bluetooth.enable = true; } else {})
			// (if inputs.config.nixos.hardware.joystick.enable then { xone.enable = true; xpadneo.enable = true; } else {})
			// (if inputs.config.nixos.hardware.sound.enable then { pulseaudio.enable = false; } else {});
		services = {}
			// (if inputs.config.nixos.hardware.printer.enable then
				{
					printing = { enable = true; drivers = [ inputs.pkgs.cnijfilter2 ]; };
					avahi = { enable = true; nssmdns = true; openFirewall = true; };
				}
				else {})
			// (if inputs.config.nixos.hardware.sound.enable then
					{ pipewire = { enable = true; alsa = { enable = true; support32Bit = true; }; pulse.enable = true; }; }
				else {});
	}
	// (if inputs.config.nixos.hardware.sound.enable then
		{
			sound.enable = true;
			security.rtkit.enable = true;
			environment.etc."wireplumber/main.lua.d/50-alsa-config.lua".text =
				let
					content = builtins.readFile
						("/." + inputs.pkgs.wireplumber + "/share/wireplumber/main.lua.d/50-alsa-config.lua");
					matched = builtins.match
						".*\n([[:space:]]*)(--\\[\"session\\.suspend-timeout-seconds\"][^\n]*)[\n].*" content;
					spaces = builtins.elemAt matched 0;
					comment = builtins.elemAt matched 1;
					config = "[\"session.suspend-timeout-seconds\"] = 0";
				in
					builtins.replaceStrings [(spaces + comment)] [(spaces + config)] content;
		}
		else {});
}
