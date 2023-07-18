inputs:
{
	options.nixos.hardware = let inherit (inputs.lib) mkOption types; in
	{
		bluetooth.enable = mkOption { type = types.bool; default = false; };
		joystick.enable = mkOption { type = types.bool; default = false; };
		printer.enable = mkOption { type = types.bool; default = false; };
	};
	config =
	{
		hardware = {}
			// (if inputs.config.nixos.hardware.bluetooth.enable then { bluetooth.enable = true; } else {})
			// (if inputs.config.nixos.hardware.joystick.enable then { xone.enable = true; xpadneo.enable = true; } else {});
		services = {}
			// (if inputs.config.nixos.hardware.printer.enable then
				{
					printing = { enable = true; drivers = [ inputs.pkgs.cnijfilter2 ]; };
					avahi = { enable = true; nssmdns = true; openFirewall = true; };
				}
				else {});
	};
}
