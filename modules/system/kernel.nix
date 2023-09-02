inputs:
{
  options.nixos.system.kernel = let inherit (inputs.lib) mkOption types; in
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
  config =
    let
      inherit (inputs.lib) mkMerge mkIf;
      inherit (inputs.localLib) mkConditional;
      inherit (inputs.config.nixos.system) kernel;
    in { boot =
    {
      kernelModules = [ "br_netfilter" ] ++ kernel.modules.load;
      # modprobe --show-depends
      initrd.availableKernelModules =
      [
        "ahci" "ata_piix" "bfq" "failover" "net_failover" "nls_cp437" "nls_iso8859-1" "nvme" "sdhci_acpi" "sd_mod"
        "sr_mod" "usbcore" "usbhid" "usbip-core" "usb-common" "usb_storage" "vhci-hcd" "virtio" "virtio_blk"
        "virtio_net" "virtio_pci" "xhci_pci" "virtio_ring" "virtio_scsi" "cryptd" "crypto_simd" "libaes"
      ] ++ kernel.modules.initrd;
      extraModulePackages = kernel.modules.install;
      extraModprobeConfig = builtins.concatStringsSep "\n" kernel.modules.modprobeConfig;
      kernelParams = [ "delayacct" "acpi_osi=Linux" ];
      kernelPackages = inputs.pkgs.linuxPackagesFor (inputs.pkgs.linuxPackages_xanmod.kernel.override rec
      {
        src = inputs.pkgs.fetchFromGitHub
        {
          owner = "xanmod";
          repo = "linux";
          rev = modDirVersion;
          sha256 = "sha256-rvSQJb9MIOXkGEjHOPt3x+dqp1AysvQg7n5yYsg95fk=";
        };
        version = "6.4.12";
        modDirVersion = "6.4.12-xanmod1";
      });
      kernelPatches =
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
          builtins.map (name: { inherit name; } // patches.${name}) kernel.patches;
    };};
}
