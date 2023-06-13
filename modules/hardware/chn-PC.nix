{
	config =
	{
		nix.settings.system-features = [ "gccarch-alderlake" ];
		nixpkgs =
		{
			hostPlatform = { system = "x86_64-linux"; gcc = { arch = "alderlake"; tune = "alderlake"; }; };
			config.allowUnfree = true;
		};
	};
}
