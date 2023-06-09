{
	config.nixpkgs.config.packageOverrides = pkgs: 
	{
		wpa_supplicant = pkgs.wpa_supplicant.overrideAttrs ( attrs:
			{ patches = attrs.patches ++ [ ./xmunet.patch ]; });
	};
}
