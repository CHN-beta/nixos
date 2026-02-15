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
        # readOnly = mkOption { type = types.bool; default = !submoduleInputs.config.mountBeforeSwitch; };
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
              [ "retry=15" "x-systemd.device-timeout=15min" ]
            ];
          })
          (lib.filterAttrs (n: v: v.mountBeforeSwitch or true) nfs);
        systemd.mounts = builtins.map
          (mount:
          {
            where = mount.value.mountPoint or mount.value;
            what = mount.name;
            type = "nfs4";
            mountConfig = { ForceUnmount = true; LazyUnmount = true; TimeoutSec = 10; };
            requires = [ "network-online.target" ];
            after = [ "network-online.target" ];
            options = "actimeo=10,retrans=1,noatime,x-gvfs-hide,bg,ro";
            wantedBy = [ "multi-user.target" ];
          })
          (builtins.filter (mount: !(mount.value.mountBeforeSwitch or true)) (lib.attrsToList nfs));
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
