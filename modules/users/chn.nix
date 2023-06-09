{ pkgs, ... }@inputs:
{
	config =
	{
		users.users.chn =
		{
			isNormalUser = true;
			extraGroups = inputs.lib.intersectLists
				[ "networkmanager" "wheel" "wireshark" "libvirtd" ]
				(builtins.attrNames inputs.config.users.groups);
			passwordFile = inputs.config.sops.secrets."password/chn".path;
			shell = inputs.pkgs.zsh;
		};
		sops.secrets."password/chn".neededForUsers = true;
	};
}
