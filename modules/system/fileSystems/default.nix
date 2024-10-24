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
    # generate using: sudo mdadm --examine --scan
    mdadm = mkOption { type = types.nullOr types.lines; default = null; };
    swap = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
    # device or { device, offset }
    resume = mkOption
    {
      type = types.nullOr (types.oneOf [ types.nonEmptyStr (types.submodule { options =
        { device = mkOption { type = types.nonEmptyStr; }; offset = mkOption { type = types.ints.unsigned; }; };
      })]);
      default = null;
    };
    rollingRootfs = mkOption
    {
      type = types.nullOr (types.submodule { options =
      {
        device = mkOption { type = types.nonEmptyStr; default = inputs.config.fileSystems."/".device; };
        path = mkOption { type = types.nonEmptyStr; default = "/nix/rootfs"; };
        waitDevices = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
      };});
      default = null;
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
    # mdadm
    (inputs.lib.mkIf (fileSystems.mdadm != null)
      { boot.initrd.services.swraid = { enable = true; mdadmConf = fileSystems.mdadm; }; }
    )
    # swap
    { swapDevices = builtins.map (device: { device = device; }) fileSystems.swap; }
    # resume
    (inputs.lib.mkIf (fileSystems.resume != null) { boot =
    (
      if builtins.typeOf fileSystems.resume == "string" then
        { resumeDevice = fileSystems.resume; }
      else
      {
        resumeDevice = fileSystems.resume.device;
        kernelModules = [ "resume_offset=${builtins.toString fileSystems.resume.offset}" ];
      }
    );})
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
              inherit (fileSystems.rollingRootfs) device path waitDevices;
              waitDevice = builtins.concatStringsSep "\n" (builtins.map
                (device: "while ! [ -e ${device} ]; do sleep 1; done") (waitDevices ++ [ device ]));
            in
            ''
              while ! lsmod | grep -q btrfs; do sleep 1; done
              ${waitDevice}
              mount ${device} /mnt -m
              if [ -f /mnt${path}/current/.timestamp ]
              then
                timestamp=$(cat /mnt${path}/current/.timestamp)
                subvolid=$(btrfs subvolume show /mnt${path}/current | grep 'Subvolume ID:' | awk '{print $NF}')
                mv /mnt${path}/current /mnt${path}/$timestamp-$subvolid
                btrfs property set -ts /mnt${path}/$timestamp-$subvolid ro true
              fi
              btrfs subvolume create /mnt${path}/current
              chattr +C /mnt${path}/current
              echo $(date '+%Y%m%d%H%M%S') > /mnt${path}/current/.timestamp
              umount /mnt
            '';
        };
      };
    })
  ];
}


