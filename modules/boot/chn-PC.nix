inputs:
{
	config =
	{

		# filesystem mount
		fileSystems =
		{
			"/" =
			{
				device = "tmpfs";
				fsType = "tmpfs";
				options = [ "size=16G" "relatime" "mode=755" ];
			};
			# Disable CoW for VM image and database:
			# sudo chattr +C images
			# zstd:15 cause sound stuttering
			# From btrfs wiki: 1-3 are real-time, 4-8 slower with improved compression,
			#	 9-15 try even harder though the resulting size may not be significantly improved.
			# https://btrfs.readthedocs.io/en/latest/Compression.html
			"/nix" =
			{
				device = "/dev/mapper/root";
				fsType = "btrfs";
				options = [ "subvol=nix" "compress-force=zstd:8" ];
			};
			"/boot" =
			{
				device = "/dev/disk/by-uuid/02e426ec-cfa2-4a18-b3a5-57ef04d66614";
				fsType = "btrfs";
				options = [ "compress-force=zstd:15" ];
			};
			"/boot/efi" =
			{
				device = "/dev/disk/by-uuid/3F57-0EBE";
				fsType = "vfat";
			};
		};
		# sudo btrfs fi mkswapfile --size 64g --uuid clear swap
		# sudo btrfs inspect-internal map-swapfile -r swap
		swapDevices = [ { device = "/nix/swap/swap"; } ];

		# kernel, modules, ucode
		boot.kernelPackages = inputs.pkgs.linuxPackages_xanmod_latest;
		hardware.cpu.intel.updateMicrocode = true;
		# modules auto loaded in stage2
		boot.kernelModules = [ "kvm-intel" "br_netfilter" ];
		# modules install but not auto loaded
		# boot.extraModulePackages = [ yourmodulename ];
		boot.extraModprobeConfig =
		''
			options kvm_intel nested=1
			options iwlmvm power_scheme=1
			options iwlwifi uapsd_disable=1
		'';
		boot.kernelParams = [ "delayacct" "acpi_osi=Linux" "resume_offset=41696016" ];
		boot.resumeDevice = "/dev/mapper/root";

		# grub
		boot.loader =
		{
			timeout = 5;
			efi = { canTouchEfiVariables = true; efiSysMountPoint = "/boot/efi"; };
			grub =
			{
				enable = true;
				# for BIOS, set disk to install; for EFI, set nodev
				device = "nodev";
				efiSupport = true;
				useOSProber = false;
				extraEntries =
				''
					menuentry "Windows" {
						insmod part_gpt
						insmod fat
						insmod search_fs_uuid
						insmod chain
						search --fs-uuid --set=root 7317-1DB6
						chainloader /EFI/Microsoft/Boot/bootmgfw.efi
					}
					menuentry "Windows for malware" {
						insmod part_gpt
						insmod fat
						insmod search_fs_uuid
						insmod chain
						search --fs-uuid --set=root 7321-FA9C
						chainloader /EFI/Microsoft/Boot/bootmgfw.efi
					}
				'';
			};
		};

		# initrd, luks
		boot.initrd =
		{
			systemd.enable = true;
			# modules in initrd
			# modprobe --show-depends
			availableKernelModules =
			[
				"ahci" "bfq" "i915" "intel_cstate" "nls_cp437" "nls_iso8859-1" "nvidia" "nvidia_drm" "nvidia_modeset"
				"nvidia_uvm" "nvme" "sr_mod" "usbhid" "usb_storage" "virtio_blk" "virtio_pci" "xhci_pci"
			]
			# speed up luks decryption
			++ [ "aesni_intel" "cryptd" "crypto_simd" "libaes" ];
			luks =
			{
				devices.root =
				{
					device = "/dev/disk/by-uuid/55fdd19f-0f1d-4c37-bd4e-6df44fc31f26";
					allowDiscards = true;
					bypassWorkqueues = true;
					crypttabExtraOpts = [ "fido2-device=auto" ];
				};
			};
		};

		# impermanence
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

		# services
		systemd.services.nix-daemon =
			{ environment = { TMPDIR = "/var/cache/nix"; }; serviceConfig = { CacheDirectory = "nix"; }; };
		services =
		{
			snapper.configs.impermanence =
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
			udev.extraRules =
			''
				ACTION=="add|change", KERNEL=="[sv]d[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="bfq"
				ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="bfq"
			'';
		};
	};
}
