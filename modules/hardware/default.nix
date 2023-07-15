inputs:
{
	options.nixos.hardware = let inherit (inputs.lib) mkOption types; in
	{
		bluetooth.enable = mkOption { type = types.bool; default = false; };
		joystick.enable = mkOption { type = types.bool; default = false; };
	};
	config.hardware = { bluetooth.enable = inputs.config.nixos.hardware.bluetooth.enable; }
		// (if inputs.config.nixos.hardware.joystick.enable then { xone.enable = true; xpadneo.enable = true; } else {});
}
