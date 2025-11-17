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
        neededForBoot = mkOption { type = types.bool; default = true; };
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
                (inputs.lib.optionals (device.value.neededForBoot or true)
                  [ "retry=15" "x-systemd.device-timeout=15min" ])
                (inputs.lib.optionals (!(device.value.neededForBoot or true))
                  [ "bg" "x-systemd.requires=network-online.target" "x-systemd.after=network-online.target" ])
              ];
            };
          })
          (inputs.localLib.attrsToList nfs));
        services.rpcbind.enable = true;
      }
      (inputs.lib.mkIf (builtins.any (mount: mount.neededForBoot or true) (builtins.attrValues nfs))
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
