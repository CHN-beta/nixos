{
	description = "CNH's NixOS Flake";

	inputs =
	{
		nixpkgs.url = "github:CHN-beta/nixpkgs/nixos-unstable";
		nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-23.05";
		flake-utils.url = "github:numtide/flake-utils";
		flake-utils-plus =
		{
			url = "github:gytis-ivaskevicius/flake-utils-plus";
			inputs.flake-utils.follows = "flake-utils";
		};
		flake-compat = { url = "github:edolstra/flake-compat"; flake = false; };
		flake-parts =
		{
			url = "github:hercules-ci/flake-parts";
			inputs.nixpkgs-lib.follows = "nixpkgs";
		};
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
				flake-utils-plus.follows = "flake-utils-plus";
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
		impermanence.url = "github:nix-community/impermanence";
		qchem =
		{
			url = "github:Nix-QChem/NixOS-QChem";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		nixd =
		{
			url = "github:nix-community/nixd";
			inputs =
			{
				nixpkgs.follows = "nixpkgs";
				flake-parts.follows = "flake-parts";
			};
		};
	};

	outputs = inputs:
		let
			localLib = import ./local/lib inputs.nixpkgs.lib;
			localPkgs = import ./local/pkgs;
		in
		{
			nixosConfigurations =
			{
				"chn-PC" = inputs.nixpkgs.lib.nixosSystem
				{
					system = "x86_64-linux";
					specialArgs = { topInputs = inputs; inherit localLib; };
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
											localPackages = localPkgs { inherit (args) lib; pkgs = final; };
										}
									)
									inputs.qchem.overlays.default
									(
										final: prev: { nur-xddxdd =
											(inputs.nur-xddxdd.overlays.custom args.config.boot.kernelPackages.nvidia_x11) final prev; }
									)
									inputs.nixd.overlays.default
								];
								config.allowUnfree = true;
							};
						})
						(
							localLib.mkModules
							[
								./modules/fileSystems
								./modules/kernel
								./modules/hardware
								./modules/packages
								./modules/boot
								./modules/system
								./modules/virtualization
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
													"/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
												};
											};
											decrypt.auto =
											{
												"/dev/disk/by-uuid/55fdd19f-0f1d-4c37-bd4e-6df44fc31f26" = { mapper = "root"; ssd = true; };
												"/dev/md/swap" = { mapper = "swap"; ssd = true; before = [ "root" ]; };
											};
											mdadm =
												"ARRAY /dev/md/swap metadata=1.2 name=chn-PC:swap UUID=2b546b8d:e38007c8:02990dd1:df9e23a4";
											swap = [ "/dev/mapper/swap" ];
											resume = "/dev/mapper/swap";
											rollingRootfs = { device = "/dev/mapper/root"; path = "/nix/rootfs"; };
										};
										kernel =
										{
											patches = [ "hdmi" "cjktty" "preempt" ];
											modules.modprobeConfig = [ "options iwlmvm power_scheme=1" "options iwlwifi uapsd_disable=1" ];
										};
										hardware =
										{
											cpu = [ "intel" ];
											gpu = [ "intel" "nvidia" ];
											bluetooth.enable = true;
											joystick.enable = true;
											printer.enable = true;
											sound.enable = true;
										};
										packages =
										{
											packages =
											[
												"genshin-impact" "honkers-starrail" "steam" "wine"
											];
										};
										boot.grub =
										{
											entries = localLib.stripeTabs
											''
												menuentry "Windows" {
													insmod part_gpt
													insmod fat
													insmod search_fs_uuid
													insmod chain
													search --fs-uuid --set=root 7317-1DB6
													chainloader /EFI/Microsoft/Boot/bootmgfw.efi
												}
												menuentry "Windows for malware" {
													insmod part_gpt
													insmod fat
													insmod search_fs_uuid
													insmod chain
													search --fs-uuid --set=root 7321-FA9C
													chainloader /EFI/Microsoft/Boot/bootmgfw.efi
												}
											'';
											installDevice = "efi";
										};
										system =
										{
											hostname = "chn-PC";
											march = "alderlake";
										};
										virtualization =
										{
											waydroid.enable = true;
											docker.enable = true;
											kvmHost = { enable = true; gui = true; autoSuspend = [ "win10" "hardconnect" ]; };
											kvmGuest.enable = true;
										};
									};}
								)

								./modules/basic.nix
								./modules/fonts.nix
								[ ./modules/i18n.nix { fcitx = true; } ]
								./modules/kde.nix
								./modules/sops.nix
								./modules/boot/chn-PC.nix
								[ ./modules/hardware/nvidia-prime.nix { intelBusId = "PCI:0:2:0"; nvidiaBusId = "PCI:1:0:0"; } ]
								./modules/hardware/chn-PC.nix
								./modules/networking/samba.nix
								./modules/networking/ssh.nix
								./modules/networking/wall_client.nix
								./modules/networking/xmunet.nix
								./modules/networking/chn-PC.nix
								./modules/packages/terminal.nix
								./modules/packages/gui.nix
								./modules/packages/hpc.nix
								[ ./modules/users/root.nix {} ]
								[ ./modules/users/chn.nix {} ]
								./modules/home/root.nix
								./modules/home/chn.nix
							]
						)
					];
				};
			};
		};
}
