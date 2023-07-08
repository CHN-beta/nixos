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
	nix-alien =
	{
		url = "github:thiagokokada/nix-alien";
		inputs =
		{
			flake-compat.follows = "flake-compat";
			flake-utils.follows = "flake-utils";
			nix-index-database.follows = "nix-index-database";
		};
	};
	plasma-manager =
	{
		url = "github:pjones/plasma-manager";
		inputs = { nixpkgs.follows = "nixpkgs"; home-manager.follows = "home-manager"; };
	};
	impermanence.url = "github:nix-community/impermanence";
	qchem =
	{
		url = "github:Nix-QChem/NixOS-QChem";
		inputs.nixpkgs.follows = "nixpkgs";
	};
}
