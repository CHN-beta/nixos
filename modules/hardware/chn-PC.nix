{ pkgs, ... }@inputs:
{
	config =
	{
		nix.settings.system-features = [ "gccarch-alderlake" ];
		nixpkgs =
		{
			hostPlatform = { system = "x86_64-linux"; gcc = { arch = "alderlake"; tune = "alderlake"; }; };
			config.allowUnfree = true;
			overlays =
			[(
				final: prev: let generic-pkgs = (inputs.inputs.nixpkgs.lib.nixosSystem
				{
					system = "x86_64-linux";
					specialArgs = { inputs = inputs.inputs; };
					modules = [{ config.nixpkgs.config.allowUnfree = true; }];
				}).pkgs;
				in
				{
					mono = generic-pkgs.mono;
					python310Packages.debugpy = generic-pkgs.python310Packages.debugpy;
				}
			)];
		};
	};
}
