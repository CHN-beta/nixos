inputs:
{
  options.nixos.system.kernel = let inherit (inputs.lib) mkOption types; in
  {
    variant = mkOption
    {
      type = types.nullOr (types.enum [ "nixos" "xanmod-lts" "xanmod-latest" "cachyos" "cachyos-lts" ]);
      default = "xanmod-lts";
    };
    patches = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
    modules.modprobeConfig = mkOption { type = types.listOf types.str; default = []; };
  };
  config = let inherit (inputs.config.nixos.system) kernel; in inputs.lib.mkMerge
  [
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
          # networking for nas
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
        ]
          ++ (inputs.lib.optionals (kernel.variant != "nixos") [ "crypto_simd" ]);
        extraModulePackages = with inputs.config.boot.kernelPackages; [ v4l2loopback zenpower ];
        extraModprobeConfig = builtins.concatStringsSep "\n" kernel.modules.modprobeConfig;
        kernelParams = [ "delayacct" ];
        kernelPackages = inputs.lib.mkIf (kernel.variant != null)
        {
          nixos = inputs.pkgs.linuxPackages;
          xanmod-lts = inputs.pkgs.linuxPackages_xanmod;
          xanmod-latest = inputs.pkgs.linuxPackages_xanmod_latest;
          cachyos = inputs.pkgs.linuxPackages_cachyos;
          cachyos-lts = inputs.pkgs.linuxPackages_cachyos_lts;
        }.${kernel.variant};
        kernelPatches =
          let patches.wireguard = [{ name = "wireguard"; patch = ./wireguard.patch; }];
          in builtins.concatLists (builtins.map (name: patches.${name}) kernel.patches);
      };
    }
    # enable scx when using cachyos
    (
      inputs.lib.mkIf (builtins.elem kernel.variant [ "cachyos" "cachyos-lts" ])
        { services.scx = { enable = true; scheduler = "scx_bpfland"; }; }
    )
  ];
}
