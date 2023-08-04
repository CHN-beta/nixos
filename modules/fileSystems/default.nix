inputs:
{
	options.nixos.fileSystems = let inherit (inputs.lib) mkOption types; in
	{
		mount =
		{
			# device = mountPoint;
			vfat = mkOption { type = types.attrsOf types.nonEmptyStr; default = {}; };
			# device.subvol = mountPoint;
			btrfs = mkOption { type = types.attrsOf (types.attrsOf types.nonEmptyStr); default = {}; };
		};
		decrypt =
		{
			auto = mkOption
			{
				type = types.attrsOf (types.submodule
				{
					options =
					{
						mapper = mkOption { type = types.nonEmptyStr; };
						ssd = mkOption { type = types.bool; default = false; };
						before = mkOption { type = types.nullOr (types.listOf types.nonEmptyStr); default = null; };
					};
				});
				default = {};
			};
			manual =
			{
				enable = mkOption { type = types.bool; default = false; };
				devices = mkOption
				{
					type = types.attrsOf (types.submodule
					{
						options =
						{
							mapper = mkOption { type = types.nonEmptyStr; };
							ssd = mkOption { type = types.bool; default = false; };
						};
					});
					default = {};
				};
				delayedMount = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
			};
		};
		mdadm = mkOption { type = types.nullOr types.str; default = null; };
		swap = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
		resume = mkOption
		{
			type = types.nullOr (types.str or (types.submodule
			{
				options =
				{
					device = mkOption { type = types.nonEmptyStr; };
					offset = mkOption { type = types.ints.unsigned; };
				};
			}));
			default = null;
		};
		rollingRootfs = mkOption
		{
			type = types.nullOr (types.submodule { options =
			{
				device = mkOption { type = types.nonEmptyStr; };
				path = mkOption { type = types.nonEmptyStr; };
			}; });
			default = null;
		};
	};
	config =
		let
			inherit (builtins) listToAttrs map concatLists concatStringsSep;
			inherit (inputs.lib) mkMerge mkIf;
			inherit (inputs.localLib) stripeTabs attrsToList;
			inherit (inputs.config.nixos) fileSystems;
		in mkMerge
		[
			# mount.vfat
			{
				fileSystems = listToAttrs (map
					(device: { name = device.value; value = { device = device.name; fsType = "vfat"; }; })
					(attrsToList fileSystems.mount.vfat));
			}
			# mount.btrfs
			{
				fileSystems = listToAttrs (concatLists (map
					(
						device: map
							(
								subvol:
								{
									name = subvol.value;
									value =
									{
										device = device.name;
										fsType = "btrfs";
										options = [ "compress-force=zstd:15" "subvol=${subvol.name}" ];
									};
								}
							)
							(attrsToList device.value)
					)
					(attrsToList fileSystems.mount.btrfs)));
			}
			# decrypt.auto
			(
				mkIf (fileSystems.decrypt.auto != null)
				{
					boot.initrd =
					{
						luks.devices = (listToAttrs (map
							(
								device:
								{
									name = device.value.mapper;
									value =
									{
										device = device.name;
										allowDiscards = device.value.ssd;
										bypassWorkqueues = device.value.ssd;
										crypttabExtraOpts = [ "fido2-device=auto" "x-initrd.attach" ];
									};
								}
							)
							(attrsToList fileSystems.decrypt.auto)));
						systemd.services =
							let
								createService = device:
								{
									name = "systemd-cryptsetup@${device.value.mapper}";
									value =
									{
										before = map (device: "systemd-cryptsetup@${device}.service") device.value.before;
										overrideStrategy = "asDropin";
									};
								};
							in
								listToAttrs (map createService
									(builtins.filter (device: device.value.before != null) (attrsToList fileSystems.decrypt.auto)));
					};
				}
			)
			# decrypt.manual
			(
				mkIf (fileSystems.decrypt.manual.enable)
				{
					boot.initrd =
					{
						luks.forceLuksSupportInInitrd = true;
						systemd =
						{
							extraBin =
							{
								cryptsetup = "${inputs.pkgs.cryptsetup.bin}/bin/cryptsetup";
								usbip = "${inputs.config.boot.kernelPackages.usbip}/bin/usbip";
								sed = "${inputs.pkgs.gnused}/bin/sed";
								awk = "${inputs.pkgs.gawk}/bin/awk";
								decrypt = inputs.pkgs.writeShellScript "decrypt" (stripeTabs
								"
									modprobe vhci-hcd
									busid=$(usbip list -r 127.0.0.1 | head -n4 | tail -n1 | awk '{print $1}' | sed 's/://')
									usbip attach -r 127.0.0.1 -b $busid
									${concatStringsSep "\n" (map
										(device: ''systemd-cryptsetup attach ${device.value.mapper} ${device.name} "" fido2-device=auto''
											+ (if device.value.ssd then ",discard" else ""))
										(attrsToList fileSystems.decrypt.manual.devices))}
								");
							};
							services.wait-manual-decrypt =
							{
								wantedBy = [ "initrd-root-fs.target" ];
								before = [ "roll-rootfs.service" ];
								unitConfig.DefaultDependencies = false;
								serviceConfig.Type = "oneshot";
								script = concatStringsSep "\n" (map
									(device: "while [ ! -e /dev/mapper/${device.value.mapper} ]; do sleep 1; done")
									(attrsToList fileSystems.decrypt.manual.devices));
							};
						};
					};
					fileSystems = listToAttrs (map
						(mount: { name = mount; value.options = [ "x-systemd.device-timeout=15min" ]; })
						fileSystems.decrypt.manual.delayedMount);
				}
			)
			# mdadm
			(
				mkIf (fileSystems.mdadm != null)
					{ boot.initrd.services.swraid = { enable = true; mdadmConf = fileSystems.mdadm; }; }
			)
			# swap
			{ swapDevices = map (device: { device = device; }) fileSystems.swap; }
			# resume
			(
				mkIf (fileSystems.resume != null) { boot =
				(
					if builtins.typeOf fileSystems.resume == "string" then
						{ resumeDevice = fileSystems.resume; }
					else
					{
						resumeDevice = fileSystems.resume.device;
						kernelModules = [ "resume_offset=${fileSystems.resume.offset}" ];
					}
				);}
			)
			# rollingRootfs
			(
				mkIf (fileSystems.rollingRootfs != null)
				{
					boot.initrd.systemd.services.roll-rootfs =
					{
						wantedBy = [ "local-fs-pre.target" ];
						after = [ "cryptsetup.target" "systemd-hibernate-resume.service" ];
						before = [ "local-fs-pre.target" "sysroot.mount" ];
						unitConfig.DefaultDependencies = false;
						serviceConfig.Type = "oneshot";
						script = let inherit (fileSystems.rollingRootfs) device path; in stripeTabs
						"
							mount ${device} /mnt -m
							if [ -f /mnt${path}/current/.timestamp ]
							then
								mv /mnt${path}/current /mnt${path}/$(cat /mnt${path}/current/.timestamp)
							fi
							btrfs subvolume create /mnt${path}/current
							echo $(date '+%Y%m%d%H%M%S') > /mnt${path}/current/.timestamp
							umount /mnt
						";
					};
				}
			)
		];
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
