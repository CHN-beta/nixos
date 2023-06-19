{
	config =
	{
		nix.settings.system-features = [ "gccarch-alderlake" ];
		services.dbus.implementation = "broker";
		programs.dconf.enable = true;
		hardware.opengl.enable = true;
	};
}
