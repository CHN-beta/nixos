{ efi, timeout ? 5 }: { pkgs, ... }@inputs:
{
	config =
	{
		boot =
		{
			loader =
			{
				timeout = inputs.timeout;
				systemd-boot.enable = true;
				efi.canTouchEfiVariables = efi;
			};
			initrd.systemd.enable = true;
			kernelPackages = inputs.pkgs.linuxPackages_xanmod_latest;
		};
		hardware.enableAllFirmware = true;
	};
}
