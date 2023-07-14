{
	description = "CNH's NixOS Flake";

	inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

	outputs = inputs:
	{
		nixosConfigurations =
		{
			"good-config" = inputs.nixpkgs.lib.nixosSystem
			{
				system = "x86_64-linux";
				modules =
				[({
					nixpkgs.overlays = [(final: prev:
					{
						clang-hello = final.callPackage ({ llvmPackages }: llvmPackages.stdenv.mkDerivation
						{
							pname = "clang-hello";
							version = "0";
							phases = [ "installPhase" ];
							installPhase = "clang --version > $out";
						}) {};
					})];
				})];
			};
			"bad-config" = inputs.nixpkgs.lib.nixosSystem
			{
				system = "x86_64-linux";
				modules =
				[({
					nixpkgs.overlays = [(final: prev:
					{
						clang-hello = final.callPackage ({ llvmPackages }: llvmPackages.stdenv.mkDerivation
						{
							pname = "clang-hello";
							version = "0";
							phases = [ "installPhase" ];
							installPhase = "clang --version > $out";
						}) {};
					})];
					programs.ccache.enable = true;
					nixpkgs.config.replaceStdenv = { pkgs }: pkgs.ccacheStdenv;
				})];
			};
		};
	};
}
