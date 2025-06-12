inputs:
{
  imports = inputs.localLib.findModules ./.;
  options.nixos.system.fileSystems = let inherit (inputs.lib) mkOption types; in
  {
    mount =
    {
      # device = mountPoint;
      vfat = mkOption { type = types.attrsOf types.nonEmptyStr; default = {}; };
      # device.subvol = mountPoint;
      btrfs = mkOption { type = types.attrsOf (types.attrsOf types.nonEmptyStr); default = {}; };
    };
    swap = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
    # device or { device, offset }
    resume = mkOption
    {
      type = types.nullOr (types.oneOf [ types.nonEmptyStr (types.submodule { options =
        { device = mkOption { type = types.nonEmptyStr; }; offset = mkOption { type = types.ints.unsigned; }; };
      })]);
      default = let inherit (inputs.config.nixos.system.fileSystems) swap; in
        if builtins.length swap == 1
          then if inputs.lib.hasPrefix "/dev/" (builtins.head swap) then builtins.head swap else null
          else null;
    };
    rollingRootfs = mkOption
    {
      type = types.nullOr (types.submodule { options =
      {
        waitDevices = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
      };});
      default = {};
    };
  };
  config = let inherit (inputs.config.nixos.system) fileSystems; in inputs.lib.mkMerge
  [
    # mount.vfat
    {
      fileSystems = builtins.listToAttrs (builtins.map
        (device:
        {
          name = device.value;
          value = { device = device.name; fsType = "vfat"; neededForBoot = true; options = [ "noatime" ]; };
        })
        (inputs.localLib.attrsToList fileSystems.mount.vfat));
    }
    # mount.btrfs
    # Disable CoW for VM image and database: sudo chattr +C images
    # resize btrfs:
    # sudo btrfs filesystem resize -50G /nix
    # sudo cryptsetup status root
    # sudo cryptsetup -b 3787456512 resize root
    # sudo cfdisk /dev/nvme1n1p3
    {
      fileSystems =  builtins.listToAttrs (builtins.concatLists (builtins.map
        (device: builtins.map
          (
            subvol:
            {
              name = subvol.value;
              value =
              {
                device = device.name;
                fsType = "btrfs";
                # zstd:15 cause sound stuttering
                # test on e20dae7d8b317f95718b5f4175bd4246c09735de mathematica ~15G
                # zstd:15 5m33s 7.16G
                # zstd:8 54s 7.32G
                # zstd:3 17s 7.52G
                options = [ "compress-force=zstd" "subvol=${subvol.name}" "acl" "noatime" ];
                neededForBoot = true;
              };
            }
          )
          (inputs.localLib.attrsToList device.value)
        )
        (inputs.localLib.attrsToList fileSystems.mount.btrfs)));
    }
    # swap
    { swapDevices = builtins.map (device: { device = device; }) fileSystems.swap; }
    # resume
    (inputs.lib.mkIf (fileSystems.resume != null)
    {
      boot = inputs.localLib.mkConditional (builtins.typeOf fileSystems.resume == "string")
        { resumeDevice = fileSystems.resume; }
        {
          resumeDevice = fileSystems.resume.device;
          kernelParams = [ "resume_offset=${builtins.toString fileSystems.resume.offset}" ];
        };
      nixos.system.kernel.patches = [ "hibernate-progress" ];
    })
    # rollingRootfs
    (inputs.lib.mkIf (fileSystems.rollingRootfs != null)
    {
      boot.initrd.systemd =
      {
        extraBin =
        {
          grep = "${inputs.pkgs.gnugrep}/bin/grep";
          awk = "${inputs.pkgs.gawk}/bin/awk";
          chattr = "${inputs.pkgs.e2fsprogs}/bin/chattr";
          lsmod = "${inputs.pkgs.kmod}/bin/lsmod";
        };
        services.roll-rootfs =
        {
          wantedBy = [ "initrd.target" ];
          after = [ "cryptsetup.target" "systemd-hibernate-resume.service" ];
          before = [ "local-fs-pre.target" "sysroot.mount" ];
          unitConfig.DefaultDependencies = false;
          serviceConfig.Type = "oneshot";
          script =
            let
              device = inputs.config.fileSystems."/".device;
              waitDevice = builtins.concatStringsSep "\n" (builtins.map
                (device: "while ! [ -e ${device} ]; do sleep 1; done")
                (fileSystems.rollingRootfs.waitDevices ++ [ device ]));
            in
            ''
              while ! lsmod | grep -q btrfs; do sleep 1; done
              ${waitDevice}
              mount ${device} /mnt -m
              if [ -f /mnt/nix/rootfs/current/.timestamp ]
              then
                timestamp=$(cat /mnt/nix/rootfs/current/.timestamp)
                subvolid=$(btrfs subvolume show /mnt/nix/rootfs/current | grep 'Subvolume ID:' | awk '{print $NF}')
                mv /mnt/nix/rootfs/current /mnt/nix/rootfs/$timestamp-$subvolid
                btrfs property set -ts /mnt/nix/rootfs/$timestamp-$subvolid ro true
              fi
              [ -d /mnt/nix/rootfs/current ] || btrfs subvolume create /mnt/nix/rootfs/current
              mkdir -p /mnt/nix/rootfs/current/usr
              touch /mnt/nix/rootfs/current/usr/make-systemd-happy
              chattr +C /mnt/nix/rootfs/current
              echo $(date '+%Y%m%d%H%M%S') > /mnt/nix/rootfs/current/.timestamp
              umount /mnt
            '';
        };
      };
    })
  ];
}


