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
        # networking for nas
        "igb"
        # yogabook keyboard
        "lenovo-yogabook"
      ] ++ kernel.modules.initrd;
      extraModulePackages = (with inputs.config.boot.kernelPackages; [ v4l2loopback ]) ++ kernel.modules.install;
      extraModprobeConfig = builtins.concatStringsSep "\n" kernel.modules.modprobeConfig;
      kernelParams = [ "delayacct" "acpi_osi=Linux" ];
      kernelPackages = inputs.pkgs.linuxPackages_xanmod_latest;
      kernelPatches =
        let
          patches =
          {
            cjktty =
            {
              patch = inputs.pkgs.fetchurl
              {
                url =
                  let
                    version = builtins.splitVersion inputs.config.boot.kernelPackages.kernel.version;
                    major = builtins.elemAt version 0;
                    minor = builtins.elemAt version 1;
                  in "https://raw.githubusercontent.com/zhmars/cjktty-patches/master/"
                    + "v${major}.x/cjktty-${major}.${minor}.patch";
                sha256 = "0ckmbx53js04lrcvcsf8qk935v2pl9w0af2v1mqghfs0krakfgfh";
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
