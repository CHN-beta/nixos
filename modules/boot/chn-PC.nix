inputs:
{
	config =
	{
		# filesystem mount
		# sudo btrfs fi mkswapfile --size 64g --uuid clear swap
		# sudo btrfs inspect-internal map-swapfile -r swap
		# sudo mdadm --create /dev/md/swap --level 0 --raid-devices 2 /dev/nvme1n1p5 /dev/nvme0n1p5
		# sudo mkswap --uuid clear /dev/md/swap
		# sudo cryptsetup luksFormat /dev/md/swap
		# sudo systemd-cryptenroll --fido2-device=auto /dev/md/swap
		# sudo systemd-cryptenroll --wipe-slot=0 /dev/md/swap
		# sudo $(dirname $(realpath $(which systemctl)))/../lib/systemd/systemd-cryptsetup \
		#		attach swap /dev/md/swap - fido2-device=auto
		# sudo mkswap --uuid clear /dev/mapper/swap

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
		boot.kernelParams = [ "delayacct" "acpi_osi=Linux" ];
		boot.kernelPatches =
		[
			{ name = "hdmi"; patch = ./hdmi.patch; }
			{
				name = "cjktty";
				patch = inputs.pkgs.fetchurl
				{
					url = "https://raw.githubusercontent.com/zhmars/cjktty-patches/master/v6.x/cjktty-6.4.patch";
					sha256 = "sha256-oGZxvg6ldpPAn5+W+r/e/WkVO92iv0XVFoJfFF5rdc8=";
				};
				extraStructuredConfig = { FONT_CJK_16x16 = inputs.lib.kernel.yes; FONT_CJK_32x32 = inputs.lib.kernel.yes; };
			}
			{
				name = "custom config";
				patch = null;
				extraStructuredConfig =
				{
					GENERIC_CPU = inputs.lib.kernel.no;
					MALDERLAKE = inputs.lib.kernel.yes;
					PREEMPT_VOLUNTARY = inputs.lib.mkForce inputs.lib.kernel.no;
					PREEMPT = inputs.lib.mkForce inputs.lib.kernel.yes;
					HZ_500 = inputs.lib.mkForce inputs.lib.kernel.no;
					HZ_1000 = inputs.lib.mkForce inputs.lib.kernel.yes;
					HZ = inputs.lib.mkForce (inputs.lib.kernel.freeform "1000");
				};
			}
		];

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
		systemd.services =
		{
			nix-daemon = { environment = { TMPDIR = "/var/cache/nix"; }; serviceConfig = { CacheDirectory = "nix"; }; };
			systemd-tmpfiles-setup = { environment = { SYSTEMD_TMPFILES_FORCE_SUBVOL = "0"; }; };
		};
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
			udev.extraRules =
			''
				ACTION=="add|change", KERNEL=="[sv]d[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="bfq"
				ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="bfq"
			'';
		};
	};
}
