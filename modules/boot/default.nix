inputs:
{
	options.nixos.boot = let inherit (inputs.lib) mkOption types; in
	{
		grub =
		{
			timeout = mkOption { type = types.int; default = 5; };
			entries = mkOption { type = types.nullOr types.str; };
			installDevice = mkOption { type = types.str; }; # "efi" using efi, or dev path like "/dev/sda" using bios
		};
	};
	config =
		let
			inherit (inputs.lib) mkMerge mkIf;
			inherit (inputs.localLib) mkConditional;
			inherit (inputs.config.nixos) boot;
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
			# grub.entries
			(
				mkIf (boot.grub.entries != null) { boot.loader.grub.extraEntries = boot.grub.entries; }
			)
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
		];
}
