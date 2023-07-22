inputs:
{
	config =
	{
		# initrd, luks
		boot.initrd.systemd.services."systemd-cryptsetup@swap" =
		{
			before = [ "systemd-cryptsetup@root.service" ];
			overrideStrategy = "asDropin";
		};

		# impermanence
		environment.persistence."/nix/persistent" =
		{
			hideMounts = true;
			directories =
			[
				"/etc/NetworkManager/system-connections"
				"/home"
				"/root"
				"/var"
			];
			files =
			[
				"/etc/machine-id"
				"/etc/ssh/ssh_host_ed25519_key.pub"
				"/etc/ssh/ssh_host_ed25519_key"
				"/etc/ssh/ssh_host_rsa_key.pub"
				"/etc/ssh/ssh_host_rsa_key"
			];
		};

		# services
		services =
		{
			snapper.configs.persistent =
			{
				SUBVOLUME = "/nix/persistent";	
				TIMELINE_CREATE = true;
				TIMELINE_CLEANUP = true;
				TIMELINE_MIN_AGE = 1800;
				TIMELINE_LIMIT_HOURLY = "10";
				TIMELINE_LIMIT_DAILY = "7";
				TIMELINE_LIMIT_WEEKLY = "1";
				TIMELINE_LIMIT_MONTHLY = "0";
				TIMELINE_LIMIT_YEARLY = "0";
			};
		};
	};
}
