# TODO: disable auto usb redirection
{ pkgs, ...}@inputs:
{
	config =
	{
		virtualisation =
		{
			libvirtd = { enable = true; qemu.runAsRoot = false; onBoot = "ignore"; onShutdown = "shutdown"; };
			spiceUSBRedirection.enable = true;
		};
		environment.systemPackages = with pkgs; [ qemu_full virt-manager win-spice ];
	};
}
