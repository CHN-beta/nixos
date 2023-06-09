{
	config =
	{
		hardware = { tuxedo-control-center.enable = true; tuxedo-keyboard.enable = true; };
		nix.settings.system-features = [ "gccarch-alderlake" ];
	};
}
