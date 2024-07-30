inputs:
{
  options.nixos.system.kernel = let inherit (inputs.lib) mkOption types; in
  {
    variant = mkOption
    {
      type = types.enum [ "nixos" "xanmod-lts" "xanmod-latest" "cachyos" "cachyos-lto" "cachyos-server" ];
      default = "xanmod-latest";
    };
    patches = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
    modules =
    {
      install = mkOption { type = types.listOf types.str; default = []; };
      load = mkOption { type = types.listOf types.str; default = []; };
      initrd = mkOption { type = types.listOf types.str; default = []; };
      modprobeConfig = mkOption { type = types.listOf types.str; default = []; };
    };
  };
  config = let inherit (inputs.config.nixos.system) kernel; in inputs.lib.mkMerge
  [
    {
      boot =
      {
        kernelModules = [ "br_netfilter" ] ++ kernel.modules.load;
        # modprobe --show-depends
        initrd.availableKernelModules =
        [
          "bfq" "failover" "net_failover" "nls_cp437" "nls_iso8859-1" "sd_mod"
          "sr_mod" "usbcore" "usbhid" "usbip-core" "usb-common" "usb_storage" "vhci-hcd" "virtio" "virtio_blk"
          "virtio_net" "virtio_ring" "virtio_scsi" "cryptd" "libaes"
          "ahci" "ata_piix" "nvme" "sdhci_acpi" "virtio_pci" "xhci_pci"
          # networking for nas
          "igb"
        ]
        ++ (inputs.lib.optionals (kernel.variant != "nixos") [ "crypto_simd" ])
        # for pi3b to show message over hdmi while boot
        ++ (inputs.lib.optionals (kernel.variant == "nixos") [ "vc4" "bcm2835_dma" "i2c_bcm2835" ]);
        extraModulePackages = (with inputs.config.boot.kernelPackages; [ v4l2loopback ]) ++ kernel.modules.install;
        extraModprobeConfig = builtins.concatStringsSep "\n" kernel.modules.modprobeConfig;
        kernelParams = [ "delayacct" ];
        kernelPackages =
        {
          nixos = inputs.pkgs.linuxPackages;
          xanmod-lts = inputs.pkgs.linuxPackages_xanmod;
          xanmod-latest = inputs.pkgs.linuxPackages_xanmod_latest;
          cachyos = inputs.pkgs.linuxPackages_cachyos;
          cachyos-lto = inputs.pkgs.linuxPackages_cachyos-lto;
          cachyos-server = inputs.pkgs.linuxPackages_cachyos-server;
          rpi3 = inputs.pkgs.linuxPackages_rpi3;
          steamos = inputs.pkgs.linuxPackages_jovian;
        }.${kernel.variant};
        kernelPatches =
          let
            patches =
            {
              cjktty =
              [{
                name = "cjktty";
                patch =
                  let version = inputs.lib.versions.majorMinor inputs.config.boot.kernelPackages.kernel.version;
                  in "${inputs.topInputs.cjktty}/v6.x/cjktty-${version}.patch";
                extraStructuredConfig =
                  { FONT_CJK_16x16 = inputs.lib.kernel.yes; FONT_CJK_32x32 = inputs.lib.kernel.yes; };
              }];
              lantian =
              [{
                name = "lantian";
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
              }];
              hibernate-progress =
              [{
                name = "hibernate-progress";
                patch =
                  let version = inputs.lib.versions.majorMinor inputs.config.boot.kernelPackages.kernel.version;
                  in ./hibernate-progress-${version}.patch;
              }];
            };
          in builtins.concatLists (builtins.map (name: patches.${name}) kernel.patches);
      };
    }
    (
      inputs.lib.mkIf
      (
        inputs.lib.strings.hasPrefix "cachyos" kernel.variant
        && builtins.elem "server-extra" inputs.config.nixos.packages._packageSets
      )
      { environment.systemPackages = [ inputs.pkgs.scx ]; }
    )
    (
      inputs.lib.mkIf (kernel.variant == "rpi3")
        { boot.initrd = { systemd.enableTpm2 = false; includeDefaultModules = false; }; }
    )
  ];
}
