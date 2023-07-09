inputs:
{
	options.nixos.fileSystems = let inherit (inputs.lib) mkOption types; in
	{
		mount =
		{
			# device = mountPoint;
			vfat = mkOption { type = types.attrsOf types.str; };
			# device.subvol = mountPoint;
			btrfs = mkOption { type = types.attrsOf (types.attrsOf types.str); };
		};
		decrypt.auto = mkOption { type = types.attrsOf (types.submodule { options =
			{ mapper = mkOption { type = types.nonEmptyStr; }; ssd = mkOption { type = types.bool; }; }; }); };

		# swap and resume
		# swap != resume.device if swap is a file
		# swap = mkOption { type = types.nullOr types.str; };
		# resume =
		# {
		# 	device = mkOption { type = types.nullOr types.str; };
		# 	# sudo btrfs fi mkswapfile --size 64g --uuid clear swap
		# 	# sudo btrfs inspect-internal map-swapfile -r swap
		# 	offset = mkOption { type = types.nullOr types.ints.unsigned; };
		# };
	};
	config =
	{
		fileSystems =
		(
			builtins.listToAttrs (builtins.map
				(device: { name = device.value; value = { device = device.name; fsType = "vfat"; }; })
				(inputs.localLib.attrsToList inputs.config.nixos.fileSystems.mount.vfat))
		)
		// (
			builtins.listToAttrs (builtins.concatLists (builtins.map
				(
					device: builtins.map
						(
							subvol:
							{
								name = subvol.value;
								value =
								{
									device = device.name;
									fsType = "btrfs";
									options = [ "compress-force=zstd:8" "subvol=${subvol.name}" ];
								};
							}
						)
						(inputs.localLib.attrsToList device.value)
				)
				(inputs.localLib.attrsToList inputs.config.nixos.fileSystems.mount.btrfs)))
		);
		boot.initrd.luks.devices =
		(
			builtins.listToAttrs (builtins.map
				(
					device:
					{
						name = device.value.mapper;
						value =
						{
							device = device.name;
							allowDiscards = device.value.ssd;
							bypassWorkqueues = device.value.ssd;
							crypttabExtraOpts = [ "fido2-device=auto" ];
						};
					}
				)
				(inputs.localLib.attrsToList inputs.config.nixos.fileSystems.decrypt.auto))
		);
	};
}

# Disable CoW for VM image and database:
# sudo chattr +C images
# zstd:15 cause sound stuttering
# From btrfs wiki: 1-3 are real-time, 4-8 slower with improved compression,
#	 9-15 try even harder though the resulting size may not be significantly improved.
# https://btrfs.readthedocs.io/en/latest/Compression.html
# sudo btrfs filesystem resize -50G /nix
# sudo cryptsetup status root
# sudo cryptsetup -b 3787456512 resize root
# sudo cfdisk /dev/nvme1n1p3
