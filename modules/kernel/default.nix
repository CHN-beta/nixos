inputs:
{
	options.nixos.kernel = let inherit (inputs.lib) mkOption types; in
	{
		patches = mkOption { type = types.listOf (types.enum [ "cjktty" "preempt" ]); default = []; };
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
				kernelModules = [ "br_netfilter" ];
				initrd.availableKernelModules =
				[
					"ahci" "ata_piix" "bfq" "failover" "net_failover" "nls_cp437" "nls_iso8859-1" "nvme" "sd_mod" "sr_mod"
					"usbcore" "usbhid" "usbip-core" "usb-common" "usb_storage" "vhci-hcd" "virtio" "virtio_blk" "virtio_net"
					"virtio_pci" "xhci_pci" "virtio_ring" "virtio_scsi" "cryptd" "crypto_simd" "libaes"
				];
				kernelParams = [ "delayacct" "acpi_osi=Linux" ];
				kernelPackages = inputs.pkgs.linuxPackages_xanmod;
			};
		}
		# patches
		{
			boot.kernelPatches =
			(
				let
					patches =
					{
						cjktty =
						{
							patch = inputs.pkgs.fetchurl
							{
								url = "https://raw.githubusercontent.com/zhmars/cjktty-patches/master/v6.x/cjktty-6.3.patch";
								sha256 = "sha256-QnsWruzhtiZnqzTUXkPk9Hb19Iddr4VTWXyV4r+iLvE=";
							};
							extraStructuredConfig =
								{ FONT_CJK_16x16 = inputs.lib.kernel.yes; FONT_CJK_32x32 = inputs.lib.kernel.yes; };
						};
						preempt =
						{
							patch = null;
							extraStructuredConfig =
							{
								PREEMPT_VOLUNTARY = inputs.lib.mkForce inputs.lib.kernel.no;
								PREEMPT = inputs.lib.mkForce inputs.lib.kernel.yes;
								HZ_500 = inputs.lib.mkForce inputs.lib.kernel.no;
								HZ_1000 = inputs.lib.mkForce inputs.lib.kernel.yes;
								HZ = inputs.lib.mkForce (inputs.lib.kernel.freeform "1000");
							};
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

# modprobe --show-depends
