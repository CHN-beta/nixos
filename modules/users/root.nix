{ pkgs, ... }@inputs:
{
	config =
	{
		users =
		{
			users.root =
			{
				passwordFile = inputs.config.sops.secrets."password/root".path;
				shell = inputs.pkgs.zsh;
			};
			mutableUsers = false;
		};
		sops.secrets."password/root".neededForUsers = true;
	};
}
