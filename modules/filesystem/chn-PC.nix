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
				device = "/dev/disk/by-uuid/8BDC-B409";
				fsType = "vfat";
			};
		};
		swapDevices = [ { device = "/nix/swap/swap"; } ];
		boot.initrd.luks =
		{
			yubikeySupport = true;
			devices.root =
			{
				device = "/dev/disk/by-partuuid/361d95a3-6e81-40a7-a9f4-ee158049a459";
				allowDiscards = true;
				yubikey =
				{
					slot = 2;
					twoFactor = true;
					gracePeriod = 120;
					keyLength = 64;
					saltLength = 16;
					storage =
					{
						device = "/dev/disk/by-uuid/8BDC-B409";
						fsType = "vfat";
						path = "/crypt-storage/default";
					};
				};
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
		services.snapper.configs.impermanence =
		{
			SUBVOLUME = "/nix/impermanence";	
			TIMELINE_CREATE = true;
			TIMELINE_CLEANUP = true;
			TIMELINE_MIN_AGE = 1800;
			TIMELINE_LIMIT_HOURLY = "10";
			TIMELINE_LIMIT_DAILY = "7";
			TIMELINE_LIMIT_WEEKLY = "1";
			TIMELINE_LIMIT_MONTHLY = "0";
			TIMELINE_LIMIT_YEARLY = "0";
		};

		# setup accroding to https://github.com/sgillespie/nixos-yubikey-luks
		# nix-shell https://github.com/sgillespie/nixos-yubikey-luks/archive/master.tar.gz
		# ykpersonalize -2 -ochal-resp -ochal-hmac
		# SALT_LENGTH=16
		# SALT="$(dd if=/dev/random bs=1 count=$SALT_LENGTH 2>/dev/null | rbtohex)"
		# read -s USER_PASSPHRASE
		# CHALLENGE="$(echo -n $SALT | openssl dgst -binary -sha512 | rbtohex)"
		# RESPONSE=$(ykchalresp -2 -x $CHALLENGE 2>/dev/null)
		# KEY_LENGTH=512
		# ITERATIONS=1000000
		# LUKS_KEY="$(echo -n $USER_PASSPHRASE | pbkdf2-sha512 $(($KEY_LENGTH / 8)) $ITERATIONS $RESPONSE | rbtohex)"
		# CIPHER=aes-xts-plain64
		# HASH=sha512
		# echo -n "$LUKS_KEY" | hextorb | cryptsetup luksFormat --cipher="$CIPHER" \ 
		#	--key-size="$KEY_LENGTH" --hash="$HASH" --key-file=- /dev/sdb5
		# mkdir -p /boot/crypt-storage
		#	echo -ne "$SALT\n$ITERATIONS" > /boot/crypt-storage/default
		# echo -n "$LUKS_KEY" | hextorb | cryptsetup open /dev/sdb5 encrypted --key-file=-
	};
}
