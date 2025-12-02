inputs:
{
  options.nixos.system.kernel = let inherit (inputs.lib) mkOption types; in
  {
    variant = mkOption
    {
      type = types.nullOr
        (types.enum [ "nixos" "xanmod-lts" "xanmod-latest" "xanmod-unstable" "cachyos" "cachyos-rc" ]);
      default = { x86_64 = "xanmod-lts"; aarch64 = "nixos"; }.${inputs.config.nixos.model.arch};
    };
    patches = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
  };
  config = let inherit (inputs.config.nixos.system) kernel; in
  {
    boot =
    {
      kernelModules = [ "br_netfilter" ];
      # modprobe --show-depends
      initrd.availableKernelModules =
      [
        "bfq" "failover" "net_failover" "nls_cp437" "nls_iso8859-1" "sd_mod"
        "sr_mod" "usbcore" "usbhid" "usbip-core" "usb-common" "usb_storage" "vhci-hcd" "virtio" "virtio_blk"
        "virtio_net" "virtio_ring" "virtio_scsi" "cryptd" "libaes"
        "ahci" "ata_piix" "nvme" "sdhci_acpi" "virtio_pci" "xhci_pci"
        # network for nas
        "igb"
        # disk for srv1
        "megaraid_sas"
        # disks for cluster
        "nfs" "nfsv4"
        # netowrk for srv1
        "bnx2x" "tg3"
        # network for srv2
        "e1000e" "igb" "atlantic" "igc" "tg3"
        # network for srv3
        "igb"
        # touchscreen for one
        "i2c-hid-acpi"
        # bridge network
        "bridge"
        # disk for nas
        "ahci" "nvme" "igc"
        # tf card for pc
        "sdhci_pci"
      ]
        # touchscreen for one
        ++ (inputs.lib.optionals (inputs.config.nixos.model.arch == "x86_64") [ "pinctrl-tigerlake" ]);
      extraModulePackages = with inputs.config.boot.kernelPackages;
      [
        v4l2loopback
        (if inputs.pkgs.stdenv.hostPlatform.linuxArch == "x86_64" then zenpower else inputs.pkgs.emptyDirectory)
      ];
      # force i2c-hid-acpi to load after pinctrl-tigerlake
      extraModprobeConfig = "softdep i2c-hid-acpi pre: pinctrl-tigerlake";
      kernelParams = inputs.lib.mkMerge
      [
        [ "delayacct" ]
        (inputs.lib.mkIf (builtins.elem "btrfs" kernel.patches) [ "btrfs.read_policy=queue" ])
      ];
      kernelPackages = inputs.lib.mkIf (kernel.variant != null)
      {
        nixos = inputs.pkgs.linuxPackages;
        xanmod-lts = inputs.pkgs.linuxPackages_xanmod;
        xanmod-latest = inputs.pkgs.linuxPackages_xanmod_latest;
        xanmod-unstable = inputs.pkgs.pkgs-unstable.linuxPackages_xanmod_latest;
        cachyos = inputs.pkgs.linuxPackages_cachyos-gcc;
        cachyos-rc = inputs.pkgs.linuxPackages_cachyos-rc;
      }.${kernel.variant};
      kernelPatches =
        let patches =
        {
          btrfs =
          [{
            name = "btrfs";
            patch = inputs.pkgs.fetchurl
            {
              url = "https://github.com/kakra/linux/pull/36.patch";
              sha256 = "0wimihsvrxib6g23jcqdbvqlkqk6nbqjswfx9bzmpm1vlvzxj8m0";
            };
            structuredExtraConfig.BTRFS_EXPERIMENTAL = inputs.lib.kernel.yes;
          }];
        };
        in builtins.concatLists (builtins.map (name: patches.${name}) kernel.patches);
    };
  };
}
