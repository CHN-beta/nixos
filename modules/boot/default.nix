inputs:
{
	options.nixos.boot = let inherit (inputs.lib) mkOption types; in
	{
		grub =
		{
			timeout = mkOption { type = types.int; default = 5; };
			windowsEntries = mkOption { type = types.attrsOf types.nonEmptyStr; default = {}; };
			installDevice = mkOption { type = types.str; }; # "efi" using efi, or dev path like "/dev/sda" using bios
		};
		network.enable = mkOption { type = types.bool; default = false; };
		sshd =
		{
			enable = mkOption { type = types.bool; default = false; };
			hostKeys = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
		};
	};
	config =
		let
			inherit (inputs.lib) mkMerge mkIf;
			inherit (inputs.localLib) mkConditional attrsToList stripeTabs;
			inherit (inputs.config.nixos) boot;
			inherit (builtins) concatStringsSep map;
		in mkMerge
		[
			# generic
			{
				boot =
				{
					loader.grub = { enable = true; useOSProber = false; };
					initrd.systemd.enable = true;
				};
			}
			# grub.timeout
			{ boot.loader.timeout = boot.grub.timeout; }
			# grub.windowsEntries
			{
				boot.loader.grub.extraEntries = concatStringsSep "" (map (system: stripeTabs
				''
					menuentry "${system.value}" {
						insmod part_gpt
						insmod fat
						insmod search_fs_uuid
						insmod chain
						search --fs-uuid --set=root ${system.name}
						chainloader /EFI/Microsoft/Boot/bootmgfw.efi
					}
				'') (attrsToList boot.grub.windowsEntries));
			}
			# grub.installDevice
			(
				mkConditional (boot.grub.installDevice == "efi")
					{
						boot.loader =
						{
							efi = { canTouchEfiVariables = true; efiSysMountPoint = "/boot/efi"; };
							grub = { device = "nodev"; efiSupport = true; };
						};
					}
					{ boot.loader.grub.device = boot.grub.installDevice; }
			)
			# network
			(
				mkIf boot.network.enable
				{ boot = { initrd.network.enable = true; kernelParams = [ "ip=dhcp" ]; }; }
			)
			# sshd
			(
				mkIf boot.sshd.enable
				{ boot.initrd.network.ssh = { enable = true; hostKeys = boot.sshd.hostKeys; };}
			)
		];
}
