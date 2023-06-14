{ pkgs, ... }@inputs:
{
	config =
	{
		environment.systemPackages = [ inputs.config.nur.repos.ataraxiasjel.proton-ge ];
		programs = let generic-pkgs = (inputs.inputs.nixpkgs.lib.nixosSystem
		{
			system = "x86_64-linux";
			specialArgs = { inputs = inputs.inputs; };
			modules =
			[
				inputs.inputs.aagl.nixosModules.default
				({ pkgs, ...}@inputs:
				{
					config.nixpkgs =
					{
						config.allowUnfree = true;
						overlays =
						[( final: prev:
						{
							anime-game-launcher = inputs.inputs.aagl.packages.x86_64-linux.anime-game-launcher;
							honkers-railway-launcher = inputs.inputs.aagl.packages.x86_64-linux.honkers-railway-launcher;
						} )];
					};
				})
			];
		}).pkgs;
		in {
			anime-game-launcher =
			{
				enable = true;
				package = generic-pkgs.anime-game-launcher;
			};
			honkers-railway-launcher =
			{
				enable = true;
				package = generic-pkgs.honkers-railway-launcher;
			};
			steam =
			{
				enable = true;
				package = generic-pkgs.steam;
			};
		};
	};
}
