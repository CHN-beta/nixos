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
					useOSProber = false;
					extraEntries =
					''
						menuentry "Windows" {
							insmod part_gpt
							insmod fat
							insmod search_fs_uuid
							insmod chain
							search --fs-uuid --set=root 7317-1DB6
							chainloader /EFI/Microsoft/Boot/bootmgfw.efi
						}
						menuentry "Windows for malware" {
							insmod part_gpt
							insmod fat
							insmod search_fs_uuid
							insmod chain
							search --fs-uuid --set=root 7321-FA9C
							chainloader /EFI/Microsoft/Boot/bootmgfw.efi
						}
					'';
				};
			};
		};
		hardware.enableAllFirmware = true;
	};
}
