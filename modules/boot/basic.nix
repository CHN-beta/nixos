{ efi }: { pkgs, ... }@inputs:
{
	config =
	{
		boot =
		{
			loader =
			{
				timeout = 5;
				systemd-boot.enable = true;
				efi.canTouchEfiVariables = efi;
			};
			initrd.systemd.enable = true;
			kernelPackages = inputs.pkgs.linuxPackages_xanmod_latest;
		};
		hardware.enableAllFirmware = true;
	};
}
