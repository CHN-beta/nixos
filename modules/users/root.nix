{ bootstrape ? false }: { pkgs, ... }@inputs:
{
	config =
	{
		users =
		{
			users.root = { shell = inputs.pkgs.zsh; }
				// (if bootstrape then { password = "0"; }
					else { passwordFile = inputs.config.sops.secrets."password/root".path; });
			mutableUsers = false;
		};
		# root password in initrd: 0000
		# currently not working, might work in the future
		# boot.initrd.secrets.${builtins.toString inputs.config.sops.secrets."password/root".path}
		# 	= builtins.toFile "root-password" "$y$j9T$EHgd1EmvM54fIkuDnrAM41$WNhog3VSAdrQXljA4I7Coy8W6iRQFQ3CLOKEH6IZzJ/";
	} // (if !bootstrape then { sops.secrets."password/root".neededForUsers = true; } else {});
}
