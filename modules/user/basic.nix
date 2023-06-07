inputs:
{
	config =
	{
		users =
		{
			users.chn =
			{
				isNormalUser = true;
				extraGroups = inputs.lib.intersectLists
					[ "networkmanager" "wheel" "wireshark" "libvirtd" ]
					(builtins.attrNames inputs.config.users.groups);
				passwordFile = config.sops.secrets."password/chn".path;
				shell = pkgs.zsh;
			};
			mutableUsers = false;
		};
		sops.secrets."password/chn".neededForUsers = true;
	};
}
