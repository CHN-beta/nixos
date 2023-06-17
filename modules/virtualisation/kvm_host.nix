# TODO: disable auto usb redirection
{ pkgs, ...}@inputs:
{
	config =
	{
		virtualisation = { libvirtd.enable = true; spiceUSBRedirection.enable = true; };
		environment.systemPackages = with pkgs; [ qemu_full virt-manager ];
	};
}
