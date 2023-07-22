inputs:
{
	options.nixos.kernel = let inherit (inputs.lib) mkOption types; in
	{
		patches = mkOption { type = types.listOf (types.enum [ "hdmi" "cjktty" ]); default = []; };
		modules =
		{
			install = mkOption { type = types.listOf types.str; default = []; };
			load = mkOption { type = types.listOf types.str; default = []; };
			initrd = mkOption { type = types.listOf types.str; default = []; };
			modprobeConfig = mkOption { type = types.listOf types.str; default = []; };
		};
	};
	config = let inherit (inputs.lib) mkMerge mkIf; inherit (inputs.localLib) mkConditional; in mkMerge
	[
		# generic
		{
			boot =
			{
				kernelParams = [ "delayacct" "acpi_osi=Linux" ];
				kernelPackages = inputs.pkgs.linuxPackagesFor (inputs.pkgs.linuxPackages_xanmod.kernel.override rec
				{
					src = inputs.pkgs.fetchFromGitHub
					{
						owner = "xanmod";
						repo = "linux";
						rev = modDirVersion;
						sha256 = "sha256-ab4AQx1ApJ9o1oqgNoJBL64tI0qpyVBm5XUC8l1yT6Q=";
					};
					version = "6.3.12";
					modDirVersion = "6.3.12-xanmod1";
					stdenv = inputs.pkgs.ccacheStdenv.override { stdenv = inputs.pkgs.linuxPackages_xanmod.kernel.stdenv; };
				});
			};
		}
		# patches
		{
			boot.kernelPatches =
			(
				let
					patches =
					{
						"hdmi" = { patch = ./hdmi.patch; };
						"cjktty" =
						{
							patch = inputs.pkgs.fetchurl
							{
								url = "https://raw.githubusercontent.com/zhmars/cjktty-patches/master/v6.x/cjktty-6.3.patch";
								sha256 = "sha256-QnsWruzhtiZnqzTUXkPk9Hb19Iddr4VTWXyV4r+iLvE=";
							};
							extraStructuredConfig =
								{ FONT_CJK_16x16 = inputs.lib.kernel.yes; FONT_CJK_32x32 = inputs.lib.kernel.yes; };
						};
					};
				in
					builtins.map (name: { inherit name; } // patches.${name}) inputs.config.nixos.kernel.patches
			);
		}
		# modules
		{
			boot =
			{
				extraModulePackages = inputs.config.nixos.kernel.modules.install;
				kernelModules = inputs.config.nixos.kernel.modules.load;
				initrd.availableKernelModules = inputs.config.nixos.kernel.modules.initrd;
				extraModprobeConfig = builtins.concatStringsSep "\n" inputs.config.nixos.kernel.modules.modprobeConfig;
			};
		}
	];
}
