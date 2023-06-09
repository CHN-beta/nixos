{
	config =
	{
		fileSystems =
		{
			"/" =
			{
				device = "/dev/mapper/root";
				fsType = "btrfs";
				options = [ "subvol=@root,compress-force=zstd:15" ];
			};
			"/swap" = {
				device = "/dev/mapper/root";
				fsType = "btrfs";
				options = [ "subvol=@swap" ];
			};
			"/boot" =
			{
				device = "/dev/disk/by-uuid/50DE-B72A";
				fsType = "vfat";
			};
		};
		swapDevices = [ { device = "/swap/swap"; } ];
		boot.initrd.luks.devices.root =
		{
			device = "/dev/disk/by-partuuid/49fe75e3-bd94-4c75-9b21-2c77a1f74c4e";
			header = "/dev/disk/by-partuuid/c341ca23-bb14-4927-9b31-a9dcc959d0f5";
			allowDiscards = true;
		};
	};
}
