{ pkgs, ... }@inputs:
{
	config =
	{
		users.users.chn =
		{
			isNormalUser = true;
			extraGroups = inputs.lib.intersectLists
				[ "networkmanager" "wheel" "wireshark" "libvirtd" "video" "audio" ]
				(builtins.attrNames inputs.config.users.groups);
			passwordFile = inputs.config.sops.secrets."password/chn".path;
			shell = inputs.pkgs.zsh;
		};
		sops.secrets."password/chn".neededForUsers = true;
		environment.persistence."/impermanence".users.chn =
		{
			directories =
			[
				"Desktop"
				"Documents"
				"Downloads"
				"Music"
				"repo"
				"Pictures"
				"Videos"

				".cache"
				".config"
				".gnupg"
				".local"
				".ssh"
				".android"
				".exa"
				".gnome"
				".Mathematica"
				".mozilla"
				".pki"
				".steam"
				".sys1og.conf"
				".tcc"
				".vim"
				".vscode"
				".Wolfram"
				".zotero"

			];
			files =
			[
				".bash_history"
				".cling_history"
				".gitconfig"
				".gtkrc-2.0"
				".root_hist"
				".viminfo"
				".zsh_history"
			];
		};
	};
}
