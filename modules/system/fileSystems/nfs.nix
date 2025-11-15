inputs:
{
  options.nixos.system.fileSystems.mount.nfs = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.attrsOf (types.oneOf
    [
      types.nonEmptyStr
      (types.submodule (submoduleInputs: { options =
      {
        mountPoint = mkOption { type = types.nonEmptyStr; };
        hard = mkOption { type = types.bool; default = true; };
        neededForBoot = mkOption { type = types.bool; default = submoduleInputs.config.hard; };
      };}))
    ]);
    default = {};
  };
  config =
    let inherit (inputs.config.nixos.system.fileSystems.mount) nfs;
    in inputs.lib.mkIf (nfs != {}) (inputs.lib.mkMerge
    [
      {
        fileSystems = builtins.listToAttrs (builtins.map
          (device:
          {
            name = device.value.mountPoint or device.value;
            value =
            {
              device = device.name;
              fsType = "nfs4";
              neededForBoot = device.value.neededForBoot or true;
              options = builtins.concatLists
              [
                [
                  "actimeo=1" # sync every seconds
                  "noatime"
                  "x-gvfs-hide" # hide in file managers (e.g. dolphin)
                ]
                # when try to mount at startup, wait 15 minutes before giving up
                (inputs.lib.optionals (device.value.hard or true) [ "retry=15" "x-systemd.device-timeout=15min" ])
                # do not fail, just try continuously in background
                # nfs4 use tcp, tcp itself will retransmit several times, which is enough
                (inputs.lib.optionals (!(device.value.hard or true))
                  [ "bg" "soft" "retrans=1" "timeo=20" "softreval" "x-systemd.requires=network-online.target" ])
              ];
            };
          })
          (inputs.localLib.attrsToList nfs));
        services.rpcbind.enable = true;
      }
      (inputs.lib.mkIf (builtins.any (mount: mount.hard or true) (builtins.attrValues nfs))
      {
        boot.initrd.systemd.extraBin =
        {
          "ifconfig" = "${inputs.pkgs.nettools}/bin/ifconfig";
          "mount.nfs" = "${inputs.pkgs.nfs-utils}/bin/mount.nfs";
          "mount.nfs4" = "${inputs.pkgs.nfs-utils}/bin/mount.nfs4";
        };
        nixos.system.initrd.network = {};
      })
    ]);
}
