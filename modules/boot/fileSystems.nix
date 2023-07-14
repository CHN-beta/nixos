inputs:
{
	options.nixos.fileSystems = let inherit (inputs.lib) mkOption types; in
	{
		mount =
		{
			# device = mountPoint;
			vfat = mkOption { type = types.attrsOf types.nonEmptyStr; };
			# device.subvol = mountPoint;
			btrfs = mkOption { type = types.attrsOf (types.attrsOf types.nonEmptyStr); };
		};
		decrypt.auto = mkOption { type = types.attrsOf (types.submodule { options =
		{
			mapper = mkOption { type = types.nonEmptyStr; };
			ssd = mkOption { type = types.bool; default = false; };
		}; }); };
		mdadm = mkOption { type = types.nullOr types.str; };
		swap = mkOption { type = types.listOf types.nonEmptyStr; };
		resume = mkOption { type = types.nullOr (types.str or (types.submodule { options =
			{ device = mkOption { type = types.nonEmptyStr; }; offset = mkOption { type = types.ints.unsigned; }; }; })); };
		rollingRootfs = mkOption { type = types.nullOr (types.submodule { options =
		{
			device = mkOption { type = types.nonEmptyStr; };
			path = mkOption { type = types.nonEmptyStr; };
		}; }); };
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
			)
			// (
				if inputs.config.nixos.fileSystems.rollingRootfs != null then
				{
					systemd.services.roll-rootfs =
					{
						wantedBy = [ "local-fs-pre.target" ];
						after = [ "cryptsetup.target" ];
						before = [ "local-fs-pre.target" ];
						unitConfig.DefaultDependencies = false;
						serviceConfig.Type = "oneshot";
						script = let inherit (inputs.config.nixos.fileSystems.rollingRootfs) device path; in
						''
							mount ${device} /mnt
							if [ -f /mnt${path}/current/.timestamp ]
							then
								mv /mnt${path}/current /mnt${path}/$(cat /mnt${path}/current/.timestamp)
							fi
							btrfs subvolume create /mnt${path}/current
							echo $(date '+%Y%m%d%H%M%S') > /mnt${path}/current/.timestamp
							umount /mnt
						'';
					};
				}
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
