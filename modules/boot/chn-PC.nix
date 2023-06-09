inputs:
{
	config =
	{
		boot =
		{
			initrd.availableKernelModules =
			[
				"ahci" "i915" "intel_cstate" "nvidia" "nvidia_drm" "nvidia_modeset" "nvidia_uvm" "nvme" "sr_mod"
				"usb_storage" "virtio_blk" "virtio_pci" "xhci_pci"
			];
			kernelModules = [ "kvm-intel" ];
			extraModulePackages = with inputs.config.boot.kernelPackages; [ cpupower ];
			extraModprobeConfig = "options kvm_intel nested=1";
			kernelParams = [ "delayacct" "acpi_osi=Linux" "resume_offset=19145984" ];
			resumeDevice = "/dev/mapper/root";
		};
		hardware.cpu.intel.updateMicrocode = true;
	};
}
