inputs:
{
  options.nixos.system.fileSystems.mount.nfs = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.attrsOf types.nonEmptyStr); default = null;
  };
  config = let inherit (inputs.config.nixos.system.fileSystems.mount) nfs; in inputs.lib.mkIf (nfs != null)
  {
    fileSystems = builtins.listToAttrs (builtins.map
      (device:
      {
        name = device.value;
        value =
        {
          device = device.name;
          fsType = "nfs";
          neededForBoot = true;
          options =
          [
            # when try to mount at startup, wait 15 minutes before giving up
            "retry=15" "x-systemd.device-timeout=15min"
            # sync every seconds
            "actimeo=1"
          ];
        };
      })
      (inputs.localLib.attrsToList nfs));
    boot.initrd =
    {
      network.enable = true;
      systemd.extraBin =
      {
        "ifconfig" = "${inputs.pkgs.nettools}/bin/ifconfig";
        "mount.nfs" = "${inputs.pkgs.nfs-utils}/bin/mount.nfs";
        "mount.nfs4" = "${inputs.pkgs.nfs-utils}/bin/mount.nfs4";
      };
    };
    services.rpcbind.enable = true;
  };
}
