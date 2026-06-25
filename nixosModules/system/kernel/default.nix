{
  lib,
  config,
  pkgs,
  flakeInputs,
  self,
  ...
}:
{
  options.nixos.system.kernel = {
    variant = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "nixos"
          "xanmod-lts"
          "xanmod-latest"
        ]
      );
      default =
        if with config.nixos.model; (arch == "x86_64" && variant == "desktop") then
          "xanmod-lts"
        else
          "nixos";
    };
    patches = lib.mkOption {
      type = lib.types.listOf lib.types.nonEmptyStr;
      default = [ ];
    };
  };
  config =
    let
      inherit (config.nixos.system) kernel;
    in
    {
      boot = {
        kernelModules = [
          "br_netfilter"
          "dm_cache"
          "dm_cache_smq"
          "dm_writecache"
        ];
        # modprobe --show-depends
        initrd = {
          availableKernelModules = [
            "bfq"
            "failover"
            "net_failover"
            "nls_cp437"
            "nls_iso8859-1"
            "sd_mod"
            "sr_mod"
            "usbcore"
            "usbhid"
            "usbip-core"
            "usb-common"
            "usb_storage"
            "vhci-hcd"
            "virtio"
            "virtio_blk"
            "virtio_net"
            "virtio_ring"
            "virtio_scsi"
            "cryptd"
            "libaes"
            "ahci"
            "ata_piix"
            "nvme"
            "sdhci_acpi"
            "virtio_pci"
            "xhci_pci"
            # network for nas
            "igb"
            # disk for srv1
            "megaraid_sas"
            # disks for cluster
            "nfs"
            "nfsv4"
            # netowrk for srv1
            "bnx2x"
            "tg3"
            # network for srv2
            "e1000e"
            "igb"
            "atlantic"
            "igc"
            "tg3"
            # network for srv3
            "igb"
            # touchscreen for one
            "i2c-hid-acpi"
            # bridge network
            "bridge"
            # disk for nas
            "ahci"
            "nvme"
            "igc"
            # tf card for pc
            "sdhci_pci"
            # to mount some fat32 disk
            "nls_ascii"
            "bcache"
          ]
          # touchscreen for one
          ++ (lib.optionals (config.nixos.model.arch == "x86_64") [ "pinctrl-tigerlake" ]);
          # to mount lvm with cache
          kernelModules = [
            "dm_cache"
            "dm_cache_smq"
            "dm_writecache"
          ];
        };
        extraModulePackages = lib.optionals (config.nixos.model.arch == "x86_64") [
          config.boot.kernelPackages.zenpower
        ];
        kernelParams = lib.mkMerge [
          [ "delayacct" ]
          (lib.mkIf (builtins.elem "btrfs" kernel.patches) [ "btrfs.read_policy=queue" ])
        ];
        kernelPackages =
          lib.mkIf (kernel.variant != null)
            {
              nixos = pkgs.linuxPackages;
              xanmod-lts = pkgs.linuxPackages_xanmod;
              xanmod-latest = pkgs.linuxPackages_xanmod_latest;
            }
            .${kernel.variant};
        kernelPatches =
          let
            version = lib.versions.majorMinor config.boot.kernelPackages.kernel.version;
            patches = {
              btrfs = [ (self.src.btrfs.${version} // { name = "btrfs"; }) ];
              asus =
                builtins.map
                  (file: {
                    name = "asus-${file}";
                    patch = "${flakeInputs.linux-asus}/${file}";
                  })
                  [
                    # copy from PKGBUILD
                    "0003-platform-x86-asus-armoury-add-support-for-FA507UV.patch"
                    "0003-platform-x86-asus-armoury-add-support-for-FA608UM.patch"
                    "0003-platform-x86-asus-armoury-add-support-for-G615LR.patch"
                    "0003-platform-x86-asus-armoury-add-support-for-G835LW.patch"
                    "0003-platform-x86-asus-armoury-add-support-for-GA403WR.patch"
                    "0003-0-4-platform-x86-asus-armoury-ppt-fixes-and-new-models.patch"
                    "0001-acpi-proc-idle-skip-dummy-wait.patch"
                    #"PATCH-asus-wmi-fixup-screenpad-brightness.patch"
                    "0070-acpi-x86-s2idle-Add-ability-to-configure-wakeup-by-A.patch"
                    "0040-workaround_hardware_decoding_amdgpu.patch"
                    "0084-enable-steam-deck-hdr.patch"
                    "sys-kernel_arch-sources-g14_files-0047-asus-nb-wmi-Add-tablet_mode_sw-lid-flip.patch"
                    "sys-kernel_arch-sources-g14_files-0048-asus-nb-wmi-fix-tablet_mode_sw_int.patch"
                    "ga403wr-fix-audio.patch"
                    "0001-platform-asus-wmi-do-not-enforce-battery.patch"
                    "0002-g614fp.patch"
                    "v4-0001-lamparray.patch"
                    "0001-platform-x86-asus-armoury-add-support-for-FX608JMR.patch"
                  ];
            };
          in
          builtins.concatLists (builtins.map (name: patches.${name}) kernel.patches);
        # TODO: remove in next release
        # CVE-2026-46331
        blacklistedKernelModules = [ "act_pedit" ];
        extraModprobeConfig = ''
          install act_pedit ${pkgs.coreutils}/bin/false
        '';
      };
    };
}
