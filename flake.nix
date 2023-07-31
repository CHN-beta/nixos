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
		in
		{
			nixosConfigurations =
			{
				"chn-PC" = inputs.nixpkgs.lib.nixosSystem
				{
					system = "x86_64-linux";
					specialArgs = { topInputs = inputs; inherit localLib; };
					modules = localLib.mkModules
					[
						(inputs: { config.nixpkgs.overlays = [(final: prev: { localPackages =
							(import ./local/pkgs { inherit (inputs) lib; pkgs = final; });})]; })
						./modules
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
								patches = [ "cjktty" "preempt" ];
								modules.modprobeConfig = [ "options iwlmvm power_scheme=1" "options iwlwifi uapsd_disable=1" ];
							};
							hardware =
							{
								cpus = [ "intel" ];
								gpus = [ "intel" "nvidia" ];
								bluetooth.enable = true;
								joystick.enable = true;
								printer.enable = true;
								sound.enable = true;
								prime =
									{ enable = true; mode = "offload"; busId = { intel = "PCI:0:2:0"; nvidia = "PCI:1:0:0"; };};
							};
							packages =
							{
								packageSet = "workstation";
								extraPackages = [ inputs.pkgs.localPackages.oneapi ];
								extraPythonPackages = [(pythonPackages:
									[ inputs.pkgs.localPackages.upho inputs.pkgs.localPackages.spectral ])];
							};
							boot.grub =
							{
								windowsEntries = { "7317-1DB6" = "Windows"; "7321-FA9C" = "Windows for malware"; };
								installDevice = "efi";
							};
							system =
							{
								hostname = "chn-PC";
								march = "alderlake";
								gui.enable = true;
							};
							virtualization =
							{
								waydroid.enable = true;
								docker.enable = true;
								kvmHost = { enable = true; gui = true; autoSuspend = [ "win10" "hardconnect" ]; };
								# kvmGuest.enable = true;
								nspawn = [ "arch" "ubuntu-22.04" ];
							};
							services =
							{
								impermanence.enable = true;
								snapper = { enable = true; configs.persistent = "/nix/persistent"; };
								fontconfig.enable = true;
								u2f.enable = true;
								sops = { enable = true; keyPathPrefix = "/nix/persistent"; };
								samba =
								{
									enable = true;
									private = true;
									hostsAllowed = "192.168. 127.";
									shares =
									{
										media.path = "/run/media/chn";
										home.path = "/home/chn";
										mnt.path = "/mnt";
										share.path = "/home/chn/share";
									};
								};
								sshd.enable = true;
								xrayClient =
								{
									enable = true;
									dns =
									{
										extraInterfaces = [ "docker0" ];
										hosts =
										{
											"mirism.one" = "216.24.188.24";
											"beta.mirism.one" = "216.24.188.24";
											"ng01.mirism.one" = "216.24.188.24";
											"debug.mirism.one" = "127.0.0.1";
										};
									};
								};
								firewall.trustedInterfaces = [ "docker0" "virbr0" ];
							};
							bugs =
							[
								"intel-hdmi" "suspend-hibernate-no-platform" "hibernate-iwlwifi" "suspend-lid-no-wakeup" "xmunet"
							];
						};})
					];
				};
				# 安装一个带加密、不带 impermanence 的系统
				# 增加 impermanence
				# 增加 initrd 中的网络
				# 使用 yubikey 解锁
				"vps6" = inputs.nixpkgs.lib.nixosSystem
				{
					system = "x86_64-linux";
					specialArgs = { topInputs = inputs; inherit localLib; };
					modules = localLib.mkModules
					[
						(inputs: { config.nixpkgs.overlays = [(final: prev: { localPackages =
							(import ./local/pkgs { inherit (inputs) lib; pkgs = final; });})]; })
						./modules
						(inputs: { config.nixos =
						{
							fileSystems =
							{
								mount =
								{
									btrfs =
									{
										"/dev/disk/by-uuid/52e6db14-f7c1-4bf0-9cee-d858613906ba"."/" = "/boot";
										"/dev/mapper/root"."/" = "/";
									};
								};
								decrypt.auto."/dev/disk/by-uuid/cc0c27bb-15b3-4932-98a9-583b426002be" =
									{ mapper = "root"; ssd = true; };
							};
							packages =
							{
								packageSet = "server";
							};
							services.sshd.enable = true;
							boot.grub.installDevice = "/dev/disk/by-path/pci-0000:05:00.0";
							system.hostname = "vps6";
						};})
					];
				};
			};
		};
}
