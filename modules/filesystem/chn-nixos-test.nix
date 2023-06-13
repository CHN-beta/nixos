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
			"/boot" =
			{
				device = "/dev/disk/by-uuid/18C6-B1F4";
				fsType = "vfat";
			};
		};
		boot.initrd.luks.devices.root =
		{
			device = "/dev/disk/by-partuuid/4f419ebd-2b49-4959-aa5f-46cfdd0cfc3e";
			header = "/dev/disk/by-partuuid/b0255c40-fd3c-4c95-9af7-4d64ad2e450f";
			allowDiscards = true;
		};
	};
}
