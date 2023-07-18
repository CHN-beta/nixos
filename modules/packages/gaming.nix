inputs:
{
	config =
	{
		environment.systemPackages = [ inputs.config.nur.repos.ataraxiasjel.proton-ge inputs.pkgs.wine ];
		programs.steam.enable = true;
	};
}
