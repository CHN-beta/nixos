{ efi, timeout ? 5 }: { pkgs, ... }@inputs:
{
	config =
	{
		boot =
		{
			loader =
			{
				timeout = timeout;
				efi = { canTouchEfiVariables = true; efiSysMountPoint = "/boot/efi"; };
				grub =
				{
					enable = true;
					# device = "/dev/disk/by-id/nvme-KINGSTON_SNVS2000G_50026B73815C12A8";
					device = "nodev";
					efiSupport = true;
					useOSProber = true;
				};
			};
		};
		hardware.enableAllFirmware = true;
	};
}
