{
	description = "CNH's NixOS Flake";

	inputs =
	{
		nixpkgs.url = "github:CHN-beta/nixpkgs/nixos-unstable";
		nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-23.05";
		home-manager = { url = "github:nix-community/home-manager/master"; inputs.nixpkgs.follows = "nixpkgs"; };
		sops-nix =
		{
			url = "github:Mic92/sops-nix";
			inputs = { nixpkgs.follows = "nixpkgs"; nixpkgs-stable.follows = "nixpkgs-stable"; };
		};
		touchix = { url = "github:CHN-beta/touchix"; inputs.nixpkgs.follows = "nixpkgs"; };
		aagl = { url = "github:ezKEa/aagl-gtk-on-nix"; inputs.nixpkgs.follows = "nixpkgs"; };
		nix-index-database = { url = "github:Mic92/nix-index-database"; inputs.nixpkgs.follows = "nixpkgs"; };
		nur.url = "github:nix-community/NUR";
		nixos-cn = { url = "github:nixos-cn/flakes"; inputs.nixpkgs.follows = "nixpkgs"; };
		nur-xddxdd = { url = "github:xddxdd/nur-packages"; inputs.nixpkgs.follows = "nixpkgs"; };
		nix-vscode-extensions = { url = "github:nix-community/nix-vscode-extensions"; inputs.nixpkgs.follows = "nixpkgs"; };
		nix-alien = { url = "github:thiagokokada/nix-alien"; inputs.nix-index-database.follows = "nix-index-database"; };
		impermanence.url = "github:nix-community/impermanence";
		qchem = { url = "github:Nix-QChem/NixOS-QChem"; inputs.nixpkgs.follows = "nixpkgs"; };
		nixd.url = "github:nix-community/nixd";
		napalm = { url = "github:nix-community/napalm"; inputs.nixpkgs.follows = "nixpkgs"; };
		nixpak = { url = "github:nixpak/nixpak"; inputs.nixpkgs.follows = "nixpkgs"; };
		deploy-rs = { url = "github:serokell/deploy-rs"; inputs.nixpkgs.follows = "nixpkgs"; };
		pnpm2nix-nzbr = { url = "github:CHN-beta/pnpm2nix-nzbr"; inputs.nixpkgs.follows = "nixpkgs"; };
	};

	outputs = inputs:
		let
			localLib = import ./local/lib inputs.nixpkgs.lib;
		in
		{
			packages.x86_64-linux.default = inputs.nixpkgs.legacyPackages.x86_64-linux.writeText "systems"
				(builtins.concatStringsSep "\n" (builtins.map
					(system: builtins.toString inputs.self.outputs.nixosConfigurations.${system}.config.system.build.toplevel)
					[ "chn-PC" "vps6" "vps4" "vps7" "nas" "xmupc1" "yoga" "pe" ]));
			nixosConfigurations = builtins.listToAttrs (builtins.map
				(system:
				{
					name = system.name;
					value = inputs.nixpkgs.lib.nixosSystem
					{
						system = "x86_64-linux";
						specialArgs = { topInputs = inputs; inherit localLib; };
						modules = localLib.mkModules
						(
							[
								(inputs: { config.nixpkgs.overlays = [(final: prev: { localPackages =
									(import ./local/pkgs { inherit (inputs) lib; pkgs = final; });})]; })
								./modules
								{ config.nixos.system.hostname = system.name; }
							]
							++ system.value
						);
					};
				})
				(localLib.attrsToList
				{
					"chn-PC" =
					[
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
								gamemode.drmDevice = 1;
							};
							packages =
							{
								packageSet = "workstation";
								extraPrebuildPackages = with inputs.pkgs; [ localPackages.oneapi llvmPackages_git.stdenv ];
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
								march = "alderlake";
								extraMarch =
								[
									# CX16
									"sandybridge"
									# CX16 SAHF FXSR
									"silvermont"
									# RDSEED MWAITX SHA CLZERO CX16 SSE4A ABM CLFLUSHOPT WBNOINVD
									"znver2" "znver3"
									# CX16 SAHF FXSR HLE RDSEED
									"broadwell"
								];
								gui.enable = true;
								keepOutputs = true;
							};
							virtualization =
							{
								waydroid.enable = true;
								docker.enable = true;
								kvmHost = { enable = true; gui = true; autoSuspend = [ "win10" "hardconnect" ]; };
								# kvmGuest.enable = true;
								nspawn = [ "arch" "ubuntu-22.04" "fedora" ];
							};
							services =
							{
								impermanence.enable = true;
								snapper = { enable = true; configs.persistent = "/nix/persistent"; };
								fontconfig.enable = true;
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
									serverAddress = "74.211.99.69";
									serverName = "vps6.xserver.chn.moe";
									dns =
									{
										extraInterfaces = [ "docker0" ];
										hosts =
										{
											"mirism.one" = "216.24.188.24";
											"beta.mirism.one" = "216.24.188.24";
											"ng01.mirism.one" = "216.24.188.24";
											"debug.mirism.one" = "127.0.0.1";
											"initrd.vps6.chn.moe" = "74.211.99.69";
											"nix-store.chn.moe" = "127.0.0.1";
										};
									};
								};
								firewall.trustedInterfaces = [ "virbr0" "waydroid0" ];
								acme =
								{
									enable = true;
									certs = [ "debug.mirism.one" ];
								};
								frpClient =
								{
									enable = true;
									serverName = "frp.chn.moe";
									user = "pc";
									tcp.store = { localPort = 443; remotePort = 7676; };
								};
								nix-serve = { enable = true; hostname = "nix-store.chn.moe"; };
								smartd.enable = true;
								nginx = { enable = true; transparentProxy.enable = false; };
								misskey = { enable = false; hostname = "xn--qbtm095lrg0bfka60z.chn.moe"; };
							};
							bugs =
							[
								"intel-hdmi" "suspend-hibernate-no-platform" "hibernate-iwlwifi" "suspend-lid-no-wakeup" "xmunet"
								"suspend-hibernate-waydroid" "embree"
							];
						};})
					];
					"vps6" = 
					[
						(inputs: { config.nixos =
						{
							fileSystems =
							{
								mount =
								{
									btrfs =
									{
										"/dev/disk/by-uuid/24577c0e-d56b-45ba-8b36-95a848228600"."/boot" = "/boot";
										"/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
									};
								};
								decrypt.manual =
								{
									enable = true;
									devices."/dev/disk/by-uuid/4f8aca22-9ec6-4fad-b21a-fd9d8d0514e8" = { mapper = "root"; ssd = true; };
									delayedMount = [ "/" ];
								};
								swap = [ "/nix/swap/swap" ];
								rollingRootfs = { device = "/dev/mapper/root"; path = "/nix/rootfs"; };
							};
							packages.packageSet = "server";
							services =
							{
								impermanence.enable = true;
								snapper = { enable = true; configs.persistent = "/nix/persistent"; };
								sops = { enable = true; keyPathPrefix = "/nix/persistent"; };
								sshd.enable = true;
								xrayServer = { enable = true; serverName = "vps6.xserver.chn.moe"; };
								frpServer = { enable = true; serverName = "frp.chn.moe"; };
								nginx =
								{
									enable = true;
									transparentProxy =
									{
										externalIp = "74.211.99.69";
										map =
										{
											"ng01.mirism.one" = 7411;
											"beta.mirism.one" = 9114;
											"nix-store.chn.moe" = 7676;
											"direct.xn--qbtm095lrg0bfka60z.chn.moe" = 7676;
										};
									};
								};
								misskey-proxy = { "xn--qbtm095lrg0bfka60z.chn.moe" = {}; "xn--s8w913fdga.chn.moe" = {}; };
								coturn.enable = true;
								synapse-proxy."synapse.chn.moe" = {};
								nebula = { enable = true; lighthouse = null; };
							};
							boot =
							{
								grub.installDevice = "/dev/disk/by-path/pci-0000:00:05.0-scsi-0:0:0:0";
								network.enable = true;
								sshd = { enable = true; hostKeys = [ "/nix/persistent/etc/ssh/initrd_ssh_host_ed25519_key" ]; };
							};
							system.march = "sandybridge";
						};})
					];
					"vps4" =
					[
						(inputs: { config.nixos =
						{
							fileSystems =
							{
								mount =
								{
									btrfs =
									{
										"/dev/disk/by-uuid/a6460ff0-b6aa-4c1c-a546-8ad0d495bcf8"."/boot" = "/boot";
										"/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
									};
								};
								decrypt.manual =
								{
									enable = true;
									devices."/dev/disk/by-uuid/46e59fc7-7bb1-4534-bbe4-b948a9a8eeda" = { mapper = "root"; ssd = true; };
									delayedMount = [ "/" ];
								};
								swap = [ "/nix/swap/swap" ];
								rollingRootfs = { device = "/dev/mapper/root"; path = "/nix/rootfs"; };
							};
							packages.packageSet = "server";
							services =
							{
								impermanence.enable = true;
								snapper = { enable = true; configs.persistent = "/nix/persistent"; };
								sops = { enable = true; keyPathPrefix = "/nix/persistent"; };
								sshd.enable = true;
							};
							boot =
							{
								grub.installDevice = "/dev/disk/by-path/pci-0000:00:04.0";
								network.enable = true;
								sshd = { enable = true; hostKeys = [ "/nix/persistent/etc/ssh/initrd_ssh_host_ed25519_key" ]; };
							};
							system.march = "znver3";
						};})
					];
					"vps7" =
					[
						(inputs: { config.nixos =
						{
							fileSystems =
							{
								mount =
								{
									btrfs =
									{
										"/dev/disk/by-uuid/e36287f7-7321-45fa-ba1e-d126717a65f0"."/boot" = "/boot";
										"/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
									};
								};
								decrypt.manual =
								{
									enable = true;
									devices."/dev/disk/by-uuid/db48c8de-bcf7-43ae-a977-60c4f390d5c4" = { mapper = "root"; ssd = true; };
									delayedMount = [ "/" ];
								};
								swap = [ "/nix/swap/swap" ];
								rollingRootfs = { device = "/dev/mapper/root"; path = "/nix/rootfs"; };
							};
							packages =
							{
								packageSet = "server";
							};
							services =
							{
								impermanence = { enable = true; nodatacow = "/nix/nodatacow"; };
								snapper = { enable = true; configs.persistent = "/nix/persistent"; };
								sops = { enable = true; keyPathPrefix = "/nix/persistent"; };
								sshd.enable = true;
								rsshub.enable = true;
								nginx = { enable = true; transparentProxy.externalIp = "95.111.228.40"; };
								wallabag.enable = true;
								misskey = { enable = true; hostname = "xn--s8w913fdga.chn.moe"; };
								synapse.enable = true;
							};
							boot =
							{
								grub.installDevice = "/dev/disk/by-path/pci-0000:00:05.0-scsi-0:0:0:0";
								network.enable = true;
								sshd = { enable = true; hostKeys = [ "/nix/persistent/etc/ssh/initrd_ssh_host_ed25519_key" ]; };
							};
							system.march = "broadwell";
						};})
					];
					"nas" =
					[
						(inputs: { config.nixos =
						{
							fileSystems =
							{
								mount =
								{
									btrfs =
									{
										"/dev/disk/by-uuid/a6460ff0-b6aa-4c1c-a546-8ad0d495bcf8"."/boot" = "/boot";
										"/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
									};
								};
								decrypt.manual =
								{
									enable = true;
									devices."/dev/disk/by-uuid/46e59fc7-7bb1-4534-bbe4-b948a9a8eeda" = { mapper = "root"; ssd = true; };
									delayedMount = [ "/" ];
								};
								swap = [ "/nix/swap/swap" ];
								rollingRootfs = { device = "/dev/mapper/root"; path = "/nix/rootfs"; };
							};
							packages.packageSet = "server";
							services =
							{
								impermanence.enable = true;
								snapper = { enable = true; configs.persistent = "/nix/persistent"; };
								sops = { enable = true; keyPathPrefix = "/nix/persistent"; };
								sshd.enable = true;
							};
							boot =
							{
								grub.installDevice = "/dev/disk/by-path/pci-0000:00:04.0";
								network.enable = true;
								sshd = { enable = true; hostKeys = [ "/nix/persistent/etc/ssh/initrd_ssh_host_ed25519_key" ]; };
							};
							system.march = "silvermont";
						};})
					];
					"xmupc1" =
					[
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
							packages.packageSet = "workstation";
							boot.grub.installDevice = "efi";
							system =
							{
								march = "znver3";
								extraMarch =
								[
									"znver2"
									# PREFETCHW RDRND XSAVE XSAVEOPT PTWRITE SGX GFNI-SSE MOVDIRI MOVDIR64B CLDEMOTE WAITPKG LZCNT
									# PCONFIG SERIALIZE HRESET KL WIDEKL AVX-VNNI
									"alderlake"
									# SAHF FXSR XSAVE
									"sandybridge"
									# SAHF FXSR PREFETCHW RDRND
									"silvermont"
								];
								gui.enable = true;
							};
							virtualization =
							{
								docker.enable = true;
								kvmHost = { enable = true; gui = true; };
							};
							services =
							{
								impermanence.enable = true;
								snapper = { enable = true; configs.persistent = "/nix/persistent"; };
								fontconfig.enable = true;
								sops = { enable = true; keyPathPrefix = "/nix/persistent"; };
								samba =
								{
									enable = true;
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
									serverAddress = "74.211.99.69";
									serverName = "vps6.xserver.chn.moe";
									dns =
									{
										extraInterfaces = [ "docker0" ];
										hosts =
										{
											"mirism.one" = "216.24.188.24";
											"beta.mirism.one" = "216.24.188.24";
											"ng01.mirism.one" = "216.24.188.24";
											"debug.mirism.one" = "127.0.0.1";
											"initrd.vps6.chn.moe" = "74.211.99.69";
											"nix-store.chn.moe" = "127.0.0.1";
										};
									};
								};
								firewall.trustedInterfaces = [ "virbr0" ];
								frpClient =
								{
									enable = true;
									serverName = "frp.chn.moe";
									user = "xmupc1";
									tcp.store = { localPort = 443; remotePort = 7676; };
								};
								smartd.enable = true;
								nginx = { enable = true; transparentProxy.enable = false; };
								postgresql.enable = true;
							};
							bugs = [ "xmunet" "firefox" "embree" ];
						};})
					];
					"yoga" =
					[
						(inputs: { config.nixos =
						{
							fileSystems =
							{
								mount =
								{
									vfat."/dev/disk/by-uuid/86B8-CF80" = "/boot/efi";
									btrfs =
									{
										"/dev/disk/by-uuid/e252f81d-b4b3-479f-8664-380a9b73cf83"."/boot" = "/boot";
										"/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
									};
								};
								decrypt.auto."/dev/disk/by-uuid/8186d34e-005c-4461-94c7-1003a5bd86c0" =
									{ mapper = "root"; ssd = true; };
								swap = [ "/nix/swap/swap" ];
								rollingRootfs = { device = "/dev/mapper/root"; path = "/nix/rootfs"; };
							};
							kernel.patches = [ "cjktty" "preempt" ];
							hardware =
							{
								cpus = [ "intel" ];
								gpus = [ "intel" ];
								bluetooth.enable = true;
								joystick.enable = true;
								printer.enable = true;
								sound.enable = true;
							};
							packages.packageSet = "desktop";
							boot.grub.installDevice = "efi";
							system =
							{
								march = "silvermont";
								gui.enable = true;
							};
							virtualization.docker.enable = true;
							services =
							{
								impermanence.enable = true;
								snapper = { enable = true; configs.persistent = "/nix/persistent"; };
								fontconfig.enable = true;
								sops = { enable = true; keyPathPrefix = "/nix/persistent"; };
								sshd.enable = true;
								xrayClient =
								{
									enable = true;
									serverAddress = "74.211.99.69";
									serverName = "vps6.xserver.chn.moe";
									dns.extraInterfaces = [ "docker0" ];
								};
								firewall.trustedInterfaces = [ "virbr0" ];
								smartd.enable = true;
							};
						};})
					];
					"pe" =
					[
						(inputs: { config.nixos =
						{
							fileSystems =
							{
								mount =
								{
									vfat."/dev/disk/by-uuid/A0F1-74E5" = "/boot/efi";
									btrfs =
									{
										"/dev/disk/by-uuid/a7546428-1982-4931-a61f-b7eabd185097"."/boot" = "/boot";
										"/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
									};
								};
								decrypt.auto."/dev/disk/by-uuid/0b800efa-6381-4908-bd63-7fa46322a2a9" =
									{ mapper = "root"; ssd = true; };
								rollingRootfs = { device = "/dev/mapper/root"; path = "/nix/rootfs"; };
							};
							kernel.patches = [ "cjktty" "preempt" ];
							hardware =
							{
								cpus = [ "intel" ];
								gpus = [ "intel" "nvidia" ];
								bluetooth.enable = true;
								joystick.enable = true;
								printer.enable = true;
								sound.enable = true;
							};
							packages.packageSet = "desktop";
							boot.grub.installDevice = "efiRemovable";
							system.gui.enable = true;
							virtualization.docker.enable = true;
							services =
							{
								impermanence.enable = true;
								snapper = { enable = true; configs.persistent = "/nix/persistent"; };
								fontconfig.enable = true;
								sops = { enable = true; keyPathPrefix = "/nix/persistent"; };
								sshd.enable = true;
								xrayClient =
								{
									enable = true;
									serverAddress = "74.211.99.69";
									serverName = "vps6.xserver.chn.moe";
									dns.extraInterfaces = [ "docker0" ];
								};
								firewall.trustedInterfaces = [ "virbr0" ];
								smartd.enable = true;
							};
						};})
					];
				}));
			# sudo HTTPS_PROXY=socks5://127.0.0.1:10884 nixos-install --flake .#bootstrap --option substituters http://127.0.0.1:5000 --option require-sigs false --option system-features gccarch-silvermont
			# nix-serve -p 5000
			# nix copy --substitute-on-destination --to ssh://server /run/current-system
			# nix copy --to ssh://nixos@192.168.122.56 ./result
			# sudo nixos-install --flake .#bootstrap
			#		--option substituters http://192.168.122.1:5000 --option require-sigs false
			# sudo chattr -i var/empty
			# nix-shell -p ssh-to-age --run 'cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age'
			# sudo nixos-rebuild switch --flake .#vps6 --log-format internal-json -v |& nom --json
			# boot.shell_on_fail systemd.setenv=SYSTEMD_SULOGIN_FORCE=1
			# sudo usbipd
			# ssh -R 3240:127.0.0.1:3240 root@192.168.122.57
			# modprobe vhci-hcd
			# sudo usbip bind -b 3-6
			# usbip attach -r 127.0.0.1 -b 3-6
			# systemd-cryptenroll --fido2-device=auto /dev/vda2
			# systemd-cryptsetup attach root /dev/vda2
			deploy =
			{
				sshUser = "root";
				user = "root";
				fastConnection = true;
				autoRollback = false;
				magicRollback = false;
				nodes = builtins.listToAttrs (builtins.map
					(node:
					{
						name = node;
						value =
						{
							hostname = node;
							profiles.system.path = inputs.self.nixosConfigurations.${node}.pkgs.deploy-rs.lib.activate.nixos
									inputs.self.nixosConfigurations.${node};
						};
					})
					[ "vps6" "vps4" "vps7" ]);
			};
		};
}
