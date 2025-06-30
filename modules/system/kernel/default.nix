inputs:
{
  options.nixos.system.kernel = let inherit (inputs.lib) mkOption types; in
  {
    variant = mkOption
    {
      type = types.nullOr (types.enum [ "nixos" "xanmod-lts" "xanmod-latest" ]);
      default = "xanmod-lts";
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
        "e1000e" "igb" "atlantic" "igc"
        # temp wireless for nas
        "r8712u"
        # network for srv3
        "igb"
        # touchscreen for one
        "pinctrl-tigerlake" "i2c-hid-acpi"
        # bridge network
        "bridge"
      ]
        ++ (inputs.lib.optionals (kernel.variant != "nixos") [ "crypto_simd" ]);
      extraModulePackages = with inputs.config.boot.kernelPackages; [ v4l2loopback zenpower ];
      # force i2c-hid-acpi to load after pinctrl-tigerlake
      extraModprobeConfig = "softdep i2c-hid-acpi pre: pinctrl-tigerlake";
      kernelParams = [ "delayacct" ];
      kernelPackages = inputs.lib.mkIf (kernel.variant != null)
      {
        nixos = inputs.pkgs.linuxPackages;
        xanmod-lts = inputs.pkgs.linuxPackages_xanmod;
        xanmod-latest = inputs.pkgs.linuxPackages_xanmod_latest;
        xanmod-unstable = inputs.pkgs.pkgs-unstable.linuxPackages_xanmod_latest;
      }.${kernel.variant};
      kernelPatches =
        let patches.hibernate-progress = [{ name = "hibernate-progress"; patch = ./hibernate-progress.patch; }];
        in builtins.concatLists (builtins.map (name: patches.${name}) kernel.patches);
    };
  };
}
