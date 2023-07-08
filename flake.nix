let
	local = import ./local;
in
	{
		description = "CNH's NixOS Flake";

		inputs = local.lib.mkInputs;

		outputs = inputs: { nixosConfigurations =
		{
			"chn-PC" = inputs.nixpkgs.lib.nixosSystem
			{
				system = "x86_64-linux";
				specialArgs = { topInputs = inputs; };
				modules =
				[
					inputs.home-manager.nixosModules.home-manager
					inputs.sops-nix.nixosModules.sops
					inputs.touchix.nixosModules.v2ray-forwarder
					inputs.aagl.nixosModules.default
					inputs.nix-index-database.nixosModules.nix-index
					inputs.nur.nixosModules.nur
					inputs.nur-xddxdd.nixosModules.setupOverlay
					inputs.impermanence.nixosModules.impermanence
					(args: {
						config.nixpkgs =
						{
							overlays =
							[
								(
									final: prev:
									{
										touchix = inputs.touchix.packages."${prev.system}";
										nix-vscode-extensions = inputs.nix-vscode-extensions.extensions."${prev.system}";
										localPackages = local.pkgs { pkgs = prev; };
									}
								)
								inputs.qchem.overlays.default
								(
									final: prev: { nur-xddxdd =
										(inputs.nur-xddxdd.overlays.custom args.config.boot.kernelPackages.nvidia_x11) final prev; }
								)
							];
							config.allowUnfree = true;
						};
					})
				];
			};
		};};
	}
