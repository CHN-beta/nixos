{ pkgs, ... }@inputs:
{
	config =
	{
		nixpkgs.overlays =
		[(
			final: prev: let generic-pkgs = (inputs.inputs.nixpkgs.lib.nixosSystem
			{
				system = "x86_64-linux";
				specialArgs = { inputs = inputs.inputs; };
				modules = [{ config.nixpkgs.config.allowUnfree = true; }];
			}).pkgs;
				in { mono = generic-pkgs.mono; }
		)];
		environment.systemPackages = [ inputs.config.nur.repos.ataraxiasjel.proton-ge ];
		programs =
		{
			anime-game-launcher.enable = true;
			honkers-railway-launcher.enable = true;
			steam.enable = true;
		};
	};
}
