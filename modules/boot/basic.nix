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
			kernelPackages = ( inputs.inputs.nixpkgs.lib.nixosSystem
			{
				system = "x86_64-linux";
				modules =
				[{
					nixpkgs =
					{
						hostPlatform = { system = "x86_64-linux"; gcc = { arch = "alderlake"; tune = "alderlake"; }; };
						config.allowUnfree = true;
					};
				}];
			} ).pkgs.linuxPackages_xanmod_latest;
		};
		hardware.enableAllFirmware = true;
	};
}
