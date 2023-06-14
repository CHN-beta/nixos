{ pkgs, ... }@inputs:
{
	config =
	{
		environment.systemPackages = [ inputs.config.nur.repos.ataraxiasjel.proton-ge ];
		programs =
		{
			anime-game-launcher.enable = true;
			honkers-railway-launcher.enable = true;
			steam.enable = true;
		};
	};
}
