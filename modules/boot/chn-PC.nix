inputs:
{
	config =
	{
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
		boot.kernelPatches = inputs.lib.mkAfter
		[
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
			systemd.services."systemd-cryptsetup@swap" =
			{
				before = [ "systemd-cryptsetup@root.service" ];
				overrideStrategy = "asDropin";
			};
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
