{ efi, timeout ? 5 }: { pkgs, ... }@inputs:
{
	config =
	{
		boot =
		{
			loader =
			{
				timeout = timeout;
				systemd-boot.enable = true;
				efi.canTouchEfiVariables = efi;
			};
			initrd.systemd.enable = true;
		};
		hardware.enableAllFirmware = true;
	};
}
