inputs:
{
	config =
	{
		boot =
		{
			initrd.availableKernelModules
				= [ "ahci" "nvme" "sr_mod" "usb_storage" "virtio_blk" "virtio_pci" "xhci_pci" ];
			kernelModules = [ "kvm-intel" ];
			extraModulePackages = with inputs.config.boot.kernelPackages; [ cpupower xone xpadneo ];
			extraModprobeConfig = "options kvm_intel nested=1";
		};
		hardware.cpu.intel.updateMicrocode = true;
	};
}
