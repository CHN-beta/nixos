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
        (inputs.lib.attrsToList fileSystems.mount.vfat));
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
                options =
                [
                  "subvol=${subvol.name}" "acl" "noatime"
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
                  "flushoncommit"
                ];
                neededForBoot = true;
              };
            }
          )
          (inputs.lib.attrsToList device.value)
        )
        (inputs.lib.attrsToList fileSystems.mount.btrfs)));
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
      systemd.sleep.settings.Sleep.HibernateMode = "reboot";
    })
  ];
}
