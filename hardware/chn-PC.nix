{ config, lib, pkgs, modulesPath, ... }:

{
	nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

	nixpkgs.config.allowUnfree = true;
	hardware = {
		enableAllFirmware = true;
		cpu.intel.updateMicrocode = true;
	};

	fileSystems = {
		"/" = {
			device = "/dev/mapper/root";
			fsType = "btrfs";
			options = [ "subvol=@root,compress-force=zstd:15" ];
		};
		"/boot" = {
			device = "/dev/disk/by-uuid/50DE-B72A";
			fsType = "vfat";
		};
	};

	boot = {
		loader = {
			timeout = 30;
			systemd-boot.enable = true;
			efi.canTouchEfiVariables = true;
		};
		initrd = {
			luks.devices.root = {
				device = "/dev/disk/by-partuuid/49fe75e3-bd94-4c75-9b21-2c77a1f74c4e";
				header = "/dev/disk/by-partuuid/c341ca23-bb14-4927-9b31-a9dcc959d0f5";
				allowDiscards = true;
			};
			systemd.enable = true;
			availableKernelModules =
			[
				"ahci" "i915" "intel_cstate" "nvidia" "nvidia_drm" "nvidia_modeset" "nvidia_uvm" "nvme" "sr_mod"
				"tuxedo-keyboard" "usb_storage" "virtio_blk" "virtio_pci" "xhci_pci" 
			];
		};
		kernelPackages = pkgs.linuxPackages_xanmod_latest;
		kernelModules = [ "kvm-intel" ];
		kernelParams = [ "delayacct" "acpi_osi=Linux" ];
		extraModulePackages = with config.boot.kernelPackages; [ cpupower xone xpadneo tuxedo-keyboard ];
		extraModprobeConfig = "options kvm_intel nested=1";
	};
}
