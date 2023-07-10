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
		decrypt.auto = mkOption { type = types.nullOr (types.attrsOf (types.submodule { options =
			{ mapper = mkOption { type = types.nonEmptyStr; }; ssd = mkOption { type = types.bool; }; }; })); };
		mdadm = mkOption { type = types.nullOr types.str; };
		swap = mkOption { type = types.listOf types.nonEmptyStr; };
		resume = mkOption { type = types.nullOr (types.str or (types.submodule { options =
			{ device = mkOption { type = types.nonEmptyStr; }; offset = mkOption { type = types.ints.unsigned; }; }; })); };

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
		swapDevices = builtins.map (device: { device = device; }) inputs.config.nixos.fileSystems.swap;
		boot =
		{
			initrd = {}
			// (
				if inputs.config.nixos.fileSystems.decrypt.auto != null then
				{
					luks.devices =
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
				}
				else {}
			)
			// (
				if inputs.config.nixos.fileSystems.mdadm != null then
					{ services.swraid = { enable = true; mdadmConf = inputs.config.nixos.fileSystems.mdadm; }; }
				else {}
			);
		}
		// (
			if inputs.config.nixos.fileSystems.resume != null then
				if builtins.typeOf inputs.config.nixos.fileSystems.resume == "string" then
					{ resumeDevice = inputs.config.nixos.fileSystems.resume; }
				else
				{
					resumeDevice = inputs.config.nixos.fileSystems.resume.device;
					kernelModules = [ "resume_offset=${inputs.config.nixos.fileSystems.resume.offset}" ];
				}
			else {}
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
