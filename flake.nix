{
	description = "CNH's NixOS Flake";

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
	};

	outputs = inputs:
		let
			local = import ./local;
		in
		{
			nixosConfigurations =
			{
				"chn-PC" = inputs.nixpkgs.lib.nixosSystem
				{
					system = "x86_64-linux";
					specialArgs = { topInputs = inputs; localLib = local.lib; };
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
						(
							local.lib.mkModules
							[
								./modules/boot/fileSystems.nix
								(inputs: { config.nixos =
									{
										fileSystems =
										{
											mount =
											{
												vfat."/dev/disk/by-uuid/3F57-0EBE" = "/boot/efi";
												btrfs =
												{
													"/dev/disk/by-uuid/02e426ec-cfa2-4a18-b3a5-57ef04d66614"."/" = "/boot";
													"/dev/mapper/root"."/nix" = "/nix";
												};
											};
										};
									};}
								)

								[ ./modules/basic.nix { hostName = "chn-PC"; } ]
								./modules/fonts.nix
								[ ./modules/i18n.nix { fcitx = true; } ]
								./modules/kde.nix
								./modules/sops.nix
								./modules/boot/chn-PC.nix
								./modules/hardware/bluetooth.nix
								./modules/hardware/joystick.nix
								[ ./modules/hardware/nvidia-prime.nix { intelBusId = "PCI:0:2:0"; nvidiaBusId = "PCI:1:0:0"; } ]
								./modules/hardware/printer.nix
								./modules/hardware/sound.nix
								./modules/hardware/chn-PC.nix
								./modules/networking/basic.nix
								./modules/networking/samba.nix
								./modules/networking/ssh.nix
								./modules/networking/wall_client.nix
								./modules/networking/xmunet.nix
								./modules/networking/chn-PC.nix
								./modules/packages/terminal.nix
								./modules/packages/gui.nix
								./modules/packages/gaming.nix
								./modules/packages/hpc.nix
								[ ./modules/users/root.nix {} ]
								[ ./modules/users/chn.nix {} ]
								./modules/virtualisation/docker.nix
								./modules/virtualisation/kvm_guest.nix
								./modules/virtualisation/kvm_host.nix
								./modules/virtualisation/waydroid.nix
								./modules/home/root.nix
								./modules/home/chn.nix
							]
						)
					];
				};
			};
		};
}
