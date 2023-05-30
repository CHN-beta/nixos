{
	description = "Chn's NixOS Flake";

	inputs =
	{
		nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
		nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-22.11";
		flake-utils.url = "github:numtide/flake-utils";
		flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };
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
			inputs = { flake-utils.follows = "flake-utils"; nixpkgs.follows = "nixpkgs-stable"; };
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

	outputs = { self, nixpkgs, home-manager, sops-nix, touchix, aagl, nix-index-database, nur, nixos-cn, ... } @inputs:
	{
		nixosConfigurations."chn-PC" = nixpkgs.lib.nixosSystem
		{
			system = "x86_64-linux";
			modules = [
				({ nixpkgs.overlays = [(final: prev: { touchix = inputs.touchix.packages."${prev.system}"; } )]; })
				./basic.nix
				./hardware/chn-PC.nix
				home-manager.nixosModules.home-manager
				sops-nix.nixosModules.sops
				touchix.nixosModules.v2ray-forwarder
				aagl.nixosModules.default
				nix-index-database.nixosModules.nix-index
				nur.nixosModules.nur
			];
		};
	};
}
