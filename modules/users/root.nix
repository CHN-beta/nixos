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
	} // (if !bootstrape then { sops.secrets."password/root".neededForUsers = true; } else {});
}
