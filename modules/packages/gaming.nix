inputs:
{
	config =
	{
		environment.systemPackages = [ inputs.config.nur.repos.ataraxiasjel.proton-ge inputs.pkgs.wine ];
		programs =
		{
			anime-game-launcher.enable = true;
			honkers-railway-launcher.enable = true;
			steam.enable = true;
		};
	};
}
