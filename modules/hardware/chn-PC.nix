{
	config =
	{
		nix.settings.system-features = [ "gccarch-alderlake" ];
		services.dbus.implementation = "broker";
	};
}
