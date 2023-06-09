# TODO: disable auto usb redirection
{ config.virtualisation = { libvirtd.enable = true; spiceUSBRedirection.enable = true; }; }
