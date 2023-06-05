{
	description = "Chn's NixOS Flake";

	inputs =
	{
		nixpkgs.url = "github:CHN-beta/nixpkgs/nixos-unstable";
		nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-23.05";
		flake-utils.url = "github:numtide/flake-utils";
		flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };
		nvfetcher =
		{
			url = "github:berberman/nvfetcher";
			inputs =
			{
				nixpkgs.follows = "nixpkgs";
				flake-utils.follows = "flake-utils";
				flake-compat.follows = "flake-compat";
			};
		};
		home-manager = { url = "github:nix-community/home-manager/master"; inputs.nixpkgs.follows = "nixpkgs"; };
		sops-nix =
		{
			url = "github:Mic92/sops-nix";
			inputs = { nixpkgs.follows = "nixpkgs"; nixpkgs-stable.follows = "nixpkgs-stable"; };
		};
		touchix = { url = "github:CHN-beta/touchix"; inputs.nixpkgs.follows = "nixpkgs"; };
		aagl =
		{
			url = "github:ezKEa/aagl-gtk-on-nix";
			inputs = { nixpkgs.follows = "nixpkgs"; flake-compat.follows = "flake-compat"; };
		};
		nix-index-database = { url = "github:Mic92/nix-index-database"; inputs.nixpkgs.follows = "nixpkgs"; };
		nur.url = "github:nix-community/NUR";
		nixos-cn =
		{
			url = "github:nixos-cn/flakes";
			inputs = { nixpkgs.follows = "nixpkgs"; flake-utils.follows = "flake-utils"; };
		};
		nur-xddxdd =
		{
			url = "github:xddxdd/nur-packages";
			inputs =
			{
				flake-utils.follows = "flake-utils";
				nixpkgs.follows = "nixpkgs-stable";
				# nvfetcher.follows = "nvfetcher";
			};
		};
		nix-vscode-extensions =
		{
			url = "github:nix-community/nix-vscode-extensions";
			inputs =
			{
				nixpkgs.follows = "nixpkgs";
				flake-utils.follows = "flake-utils";
				flake-compat.follows = "flake-compat";
			};
		};
    };

	outputs = inputs:
	{
		nixosConfigurations."chn-PC" = inputs.nixpkgs.lib.nixosSystem
		{
			system = "x86_64-linux";
			specialArgs = inputs;
			modules = [
				({ config.nixpkgs.overlays =
					[(final: prev:
					{
						touchix = inputs.touchix.packages."${prev.system}";
						nix-vscode-extensions = inputs.nix-vscode-extensions.extensions."${prev.system}";
					} )]; })
				./basic.nix
				inputs.home-manager.nixosModules.home-manager
				inputs.sops-nix.nixosModules.sops
				inputs.touchix.nixosModules.v2ray-forwarder
				inputs.aagl.nixosModules.default
				inputs.nix-index-database.nixosModules.nix-index
				inputs.nur.nixosModules.nur
			];
		};
	};
}
