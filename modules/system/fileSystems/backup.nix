{ lib, config, utils, ... }:
{
  options.nixos.system.fileSystems.backup = lib.mkOption
  {
    type = lib.types.attrsOf (lib.types.submodule { options =
    {
      device = lib.mkOption { type = lib.types.path; };
      subvol = lib.mkOption { type = lib.types.path; };
    };});
    default.persistent = { device = config.fileSystems."/".device; subvol = "/nix/persistent"; };
  };
  config = let inherit (config.nixos.system.fileSystems) backup; in
  {
    boot.initrd.systemd.services = backup
      |> lib.mapAttrs' (n: v: lib.nameValuePair "backup-${utils.escapeSystemdPath n}"
        {
          wantedBy = [ "initrd.target" ];
          after = [ "cryptsetup.target" "systemd-hibernate-resume.service" ];
          before = [ "local-fs-pre.target" "sysroot.mount" "create-needed-for-boot-dirs.service" ];
          unitConfig.DefaultDependencies = false;
          serviceConfig.Type = "oneshot";
          script = let mountPoint = "/backup-${utils.escapeSystemdPath n}"; in
          ''
            # wait for device to be available
            while [ ! -b '${v.device}' ] || ! btrfs device ready '${v.device}'; do
              sleep 1
            done

            # mount device
            mount ${v.device} ${mountPoint} -m -o noatime

            # backup subvolumes
            if [ -d ${mountPoint}${v.subvol}/.backups ]; then
              btrfs subvolume snapshot -r ${mountPoint}${v.subvol} \
                ${mountPoint}${v.subvol}/.backups/boot-$(date '+%Y%m%d%H%M%S')
            fi

            umount ${mountPoint}
          '';
        });
  };
}
