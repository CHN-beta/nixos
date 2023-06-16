{
	config =
	{
		fileSystems =
		{
			"/" =
			{
				device = "tmpfs";
				fsType = "tmpfs";
				options = [ "size=16G" "relatime" "mode=755" ];
			};
			"/nix" =
			{
				device = "/dev/mapper/root";
				fsType = "btrfs";
				options = [ "subvol=@nix" "compress-force=zstd:15" ];
			};
			"/boot" =
			{
				device = "/dev/disk/by-uuid/50DE-B72A";
				fsType = "vfat";
			};
		};
		swapDevices = [ { device = "/nix/swap/swap"; } ];
		boot.initrd.luks.devices.root =
		{
			device = "/dev/disk/by-partuuid/49fe75e3-bd94-4c75-9b21-2c77a1f74c4e";
			header = "/dev/disk/by-partuuid/c341ca23-bb14-4927-9b31-a9dcc959d0f5";
			allowDiscards = true;
		};
		environment.persistence."/nix/impermanence" =
		{
			hideMounts = true;
			directories =
			[
				# "/etc/NetworkManager/system-connections"
				"/etc"
				"/home"
				"/root"
				"/var"
			];
			# files =
			# [
			# 	"/etc/machine-id"
			# 	"/etc/ssh/ssh_host_ed25519_key.pub"
			# 	"/etc/ssh/ssh_host_ed25519_key"
			# 	"/etc/ssh/ssh_host_rsa_key.pub"
			# 	"/etc/ssh/ssh_host_rsa_key"
			# ];
		};
		systemd.services.nix-daemon =
			{ environment = { TMPDIR = "/var/cache/nix"; }; serviceConfig = { CacheDirectory = "nix"; }; };
	};
}
