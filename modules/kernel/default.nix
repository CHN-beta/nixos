inputs:
{
	options.nixos.kernel = let inherit (inputs.lib) mkOption types; in
	{
		cpu = mkOption { type = types.listOf (types.enum [ "intel" "amd" ]); default = []; };
		patches = mkOption { type = types.listOf (types.enum [ "hdmi" "cjktty" ]); default = []; };
	};
	config =
	{
		boot =
		{
			kernelParams = [ "delayacct" "acpi_osi=Linux" ];
			kernelPackages = inputs.pkgs.linuxPackages_xanmod_latest;
			kernelPatches =
			(
				let
					patches =
					{
						"hdmi" = { patch = ./hdmi.patch; };
						"cjktty" =
						{
							patch = inputs.pkgs.fetchurl
							{
								url = "https://raw.githubusercontent.com/zhmars/cjktty-patches/master/v6.x/cjktty-6.4.patch";
								sha256 = "sha256-oGZxvg6ldpPAn5+W+r/e/WkVO92iv0XVFoJfFF5rdc8=";
							};
							extraStructuredConfig =
								{ FONT_CJK_16x16 = inputs.lib.kernel.yes; FONT_CJK_32x32 = inputs.lib.kernel.yes; };
						};
					};
				in
					builtins.map (name: { inherit name; } // patches.${name}) inputs.config.nixos.kernel.patches
			);
		};
		hardware.cpu = builtins.listToAttrs (builtins.map
			(name: { inherit name; value = { updateMicrocode = true; }; })
			inputs.config.nixos.kernel.cpu);
	};
}
