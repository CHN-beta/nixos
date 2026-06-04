{ lib, config, pkgs, ... }:
{
  imports = lib.findModules ./.;
  options.nixos.system.fileSystems =
  {
    mount =
    {
      # device = mountPoint;
      vfat = lib.mkOption { type = lib.types.attrsOf lib.types.nonEmptyStr; default = {}; };
      # device.subvol = mountPoint;
      btrfs = lib.mkOption { type = lib.types.attrsOf (lib.types.attrsOf lib.types.nonEmptyStr); default = {}; };
    };
    swap = lib.mkOption { type = lib.types.listOf lib.types.nonEmptyStr; default = []; };
    # device or { device, offset }
    resume = lib.mkOption
    {
      type = lib.types.nullOr (lib.types.oneOf
      [
        lib.types.nonEmptyStr
        (lib.types.submodule
        {
          options =
          {
            device = lib.mkOption { type = lib.types.nonEmptyStr; };
            offset = lib.mkOption { type = lib.types.ints.unsigned; };
          };
        })
      ]);
      default = let inherit (config.nixos.system.fileSystems) swap; in
        if lib.length swap == 1 then if lib.hasPrefix "/dev/" (lib.head swap) then lib.head swap else null else null;
    };
  };
  config = let inherit (config.nixos.system) fileSystems; in lib.mkMerge
  [
    # mount.vfat
    {
      fileSystems = fileSystems.mount.vfat |> lib.mapAttrs'
        (n: v: lib.nameValuePair v { device = n; fsType = "vfat"; neededForBoot = true; options = [ "noatime" ]; });
    }
    # mount.btrfs
    # Disable CoW for VM image and database: sudo chattr +C images
    # resize btrfs:
    # sudo btrfs filesystem resize -50G /nix
    # sudo cryptsetup status root
    # sudo cryptsetup -b 3787456512 resize root
    # sudo cfdisk /dev/nvme1n1p3
    {
      fileSystems = fileSystems.mount.btrfs
        |> lib.mapAttrsToList (device-n: device-v: device-v
          |> lib.mapAttrs' (subvol-n: subvol-v: lib.nameValuePair subvol-v
            {
              device = device-n;
              fsType = "btrfs";
              options =
              [
                "subvol=${subvol-n}" "acl" "noatime"
                # zstd:15 cause sound stuttering
                # test on e20dae7d8b317f95718b5f4175bd4246c09735de mathematica ~15G
                # zstd:15 5m33s 7.16G
                # zstd:8 54s 7.32G
                # zstd:3 17s 7.52G
                # use compress instead of compress-force, since compress-force force all data trunk to be < 128K
                # https://github.com/Zygo/bees/issues/298#issuecomment-3085228968
                "compress=zstd"
                # large btrfs volume need more time to mount (default 90s might not be enough)
                "x-systemd.mount-timeout=300s"
                # default noflushoncommit can cause data loss, especially working with beesd, when power lost
                "flushoncommit" "commit=300"
              ];
              neededForBoot = lib.mkDefault true;
            }))
        |> lib.mergeAttrsList;
    }
    # swap
    { swapDevices = lib.map (device: { device = device; }) fileSystems.swap; }
    # resume
    (lib.mkIf (fileSystems.resume != null)
    {
      boot = lib.mkConditional (lib.typeOf fileSystems.resume == "string")
        { resumeDevice = fileSystems.resume; }
        {
          resumeDevice = fileSystems.resume.device;
          kernelParams = [ "resume_offset=${lib.toString fileSystems.resume.offset}" ];
        };
      systemd.sleep.settings.Sleep.HibernateMode = "reboot";
    })
  ];
}
