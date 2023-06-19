{ bootstrape ? false }: { pkgs, ... }@inputs:
{
	config =
	{
		users.users.chn =
		{
			isNormalUser = true;
			extraGroups = inputs.lib.intersectLists
				[ "networkmanager" "wheel" "wireshark" "libvirtd" "video" "audio" ]
				(builtins.attrNames inputs.config.users.groups);
			shell = inputs.pkgs.zsh;
			autoSubUidGidRange = true;
		} // (if bootstrape then { password = "0"; }
			else { passwordFile = inputs.config.sops.secrets."password/chn".path; });
		# environment.persistence."/impermanence".users.chn =
		# {
		# 	directories =
		# 	[
		# 		"Desktop"
		# 		"Documents"
		# 		"Downloads"
		# 		"Music"
		# 		"repo"
		# 		"Pictures"
		# 		"Videos"

		# 		".cache"
		# 		".config"
		# 		".gnupg"
		# 		".local"
		# 		".ssh"
		# 		".android"
		# 		".exa"
		# 		".gnome"
		# 		".Mathematica"
		# 		".mozilla"
		# 		".pki"
		# 		".steam"
		# 		".tcc"
		# 		".vim"
		# 		".vscode"
		# 		".Wolfram"
		# 		".zotero"

		# 	];
		# 	files =
		# 	[
		# 		".bash_history"
		# 		".cling_history"
		# 		".gitconfig"
		# 		".gtkrc-2.0"
		# 		".root_hist"
		# 		".viminfo"
		# 		".zsh_history"
		# 	];
		# };
	} // (if !bootstrape then { sops.secrets."password/chn".neededForUsers = true; } else {});
}
