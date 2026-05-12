{ lib, config, pkgs, ... }:
{
  options.nixos.system.fileSystems.mount.nfs = let inherit (lib) mkOption types; in mkOption
  {
    type = types.attrsOf (types.oneOf
    [
      types.nonEmptyStr
      (types.submodule (submoduleInputs: { options =
      {
        mountPoint = mkOption { type = types.nonEmptyStr; };
        mountBeforeSwitch = mkOption { type = types.bool; default = true; };
        readOnly = mkOption { type = types.bool; default = !submoduleInputs.config.mountBeforeSwitch; };
      };}))
    ]);
    default = {};
  };
  config = let inherit (config.nixos.system.fileSystems.mount) nfs; in lib.mkIf (nfs != {}) (lib.mkMerge
    [
      {
        fileSystems = lib.mapAttrs'
          (n: v: lib.nameValuePair (v.mountPoint or v)
          {
            device = n;
            fsType = "nfs4";
            neededForBoot = v.mountBeforeSwitch or true;
            options = builtins.concatLists
            [
              [
                "actimeo=1" # sync every seconds
                "noatime"
                "x-gvfs-hide" # hide in file managers (e.g. dolphin)
              ]
              # when try to mount at startup, wait 15 minutes before giving up
              (lib.optionals (v.mountBeforeSwitch or true) [ "retry=15" "x-systemd.device-timeout=15min" ])
              (lib.optionals (!(v.mountBeforeSwitch or true))
                [ "retry=1" "bg" "x-systemd.requires=network-online.target" "x-systemd.after=network-online.target" "x-systemd.after=tailscaled.service" ])
              (lib.optionals (v.readOnly or false) [ "ro" ])
            ];
          })
          nfs;
        systemd.mounts = builtins.map
          (mount:
          {
            where = mount.value.mountPoint or mount.value;
            what = mount.name;
            overrideStrategy = "asDropin";
            mountConfig = { ForceUnmount = true; LazyUnmount = true; TimeoutStopSec = 10; };
          })
          (builtins.filter (mount: mount.value.readOnly or false) (lib.attrsToList nfs));
        services.rpcbind.enable = true;
      }
      (lib.mkIf (builtins.any (mount: mount.mountBeforeSwitch or true) (builtins.attrValues nfs))
      {
        boot.initrd.systemd.extraBin =
        {
          "ifconfig" = "${pkgs.nettools}/bin/ifconfig";
          "mount.nfs" = "${pkgs.nfs-utils}/bin/mount.nfs";
          "mount.nfs4" = "${pkgs.nfs-utils}/bin/mount.nfs4";
        };
        nixos.system.initrd.network = {};
      })
    ]);
}
