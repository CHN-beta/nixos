topInputs: local: systems:
let
	localLib = import ./.;
	mkSystem = hostName: hostAttrs: topInputs.nixpkgs.lib.nixosSystem
	{
		system = "x86_64-linux";
		specialArgs = { inherit topInputs localLib; };
		modules =
		[
			inputs.home-manager.nixosModules.home-manager
			inputs.sops-nix.nixosModules.sops
			inputs.touchix.nixosModules.v2ray-forwarder
			inputs.aagl.nixosModules.default
			inputs.nix-index-database.nixosModules.nix-index
			inputs.nur.nixosModules.nur
			inputs.impermanence.nixosModules.impermanence
			({
				config.nixpkgs =
				{
					overlays =
					[
						( final: prev:
						{
							touchix = inputs.touchix.packages."${prev.system}";
							nix-vscode-extensions = inputs.nix-vscode-extensions.extensions."${prev.system}";
							localPackages = import ./localPackages { pkgs = prev; };
						} )
						inputs.qchem.overlays.default
					];
					config.allowUnfree = true;
				};
			})
			(
				localLib.mkModules
				[
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
in
	mapAttrs f attrset
