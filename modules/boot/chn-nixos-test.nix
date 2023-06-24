inputs:
{
	config =
	{
		boot =
		{
			kernelPackages = inputs.pkgs.linuxPackages_xanmod_latest;
			initrd.availableKernelModules = [ "ahci" "sr_mod" "usb_storage" "virtio_blk" "virtio_pci" "xhci_pci" ];
		};
	};
}
