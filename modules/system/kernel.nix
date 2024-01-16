inputs:
{
  options.nixos.system.kernel = let inherit (inputs.lib) mkOption types; in
  {
    patches = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
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
        # yoga
        "lenovo_yogabook"
      ];
      extraModulePackages = (with inputs.config.boot.kernelPackages; [ v4l2loopback ]) ++ kernel.modules.install;
      extraModprobeConfig = builtins.concatStringsSep "\n" kernel.modules.modprobeConfig;
      kernelParams = [ "delayacct" "acpi_osi=Linux" "acpi.ec_no_wakeup=1" "amdgpu.sg_display=0" ];
      blacklistedKernelModules = [ "ideapad_laptop" ];
      kernelPackages = inputs.pkgs.linuxPackages_xanmod_latest;
      kernelPatches =
        let
          patches =
          {
            cjktty =
            {
              patch =
                let
                  version = builtins.splitVersion inputs.config.boot.kernelPackages.kernel.version;
                  major = builtins.elemAt version 0;
                  minor = builtins.elemAt version 1;
                in inputs.pkgs.fetchurl
                {
                  url = "https://raw.githubusercontent.com/zhmars/cjktty-patches/master/"
                    + "v${major}.x/cjktty-${major}.${minor}.patch";
                  sha256 =
                    let
                      hashes =
                      {
                        "6.1" = "11ddiammvjxx2m9v32p25l1ai759a1d6xhdpszgnihv7g2fzigf5";
                        "6.6" = "19ib0syj3207ifr315gdrnpv6nhh435fmgl05c7k715nng40i827";
                      };
                    in hashes."${major}.${minor}";
                };
              extraStructuredConfig =
                { FONT_CJK_16x16 = inputs.lib.kernel.yes; FONT_CJK_32x32 = inputs.lib.kernel.yes; };
            };
            lantian =
            {
              patch = null;
              # pick from xddxdd/nur-packages dce93a
              extraStructuredConfig = with inputs.lib.kernel;
              {
                ACPI_PCI_SLOT = yes;
                ENERGY_MODEL = yes;
                PARAVIRT_TIME_ACCOUNTING = yes;
                PM_AUTOSLEEP = yes;
                WQ_POWER_EFFICIENT_DEFAULT = yes;
                PREEMPT_VOLUNTARY = inputs.lib.mkForce no;
                PREEMPT = inputs.lib.mkForce yes;
                NO_HZ_FULL = yes;
                HZ_1000 = inputs.lib.mkForce yes;
                HZ_250 = inputs.lib.mkForce no;
                HZ = inputs.lib.mkForce (freeform "1000");
              };
            };
          };
        in
          builtins.map (name: { inherit name; } // patches.${name}) kernel.patches;
    };};
}
