{ lib, config, pkgs, ... }:
{
  options.nixos.system.fileSystems.rollingRootfs =
    lib.mkOption { type = lib.types.nullOr (lib.types.submodule {}); default = {}; };
  config = let inherit (config.nixos.system.fileSystems) rollingRootfs; in lib.mkIf (rollingRootfs != null)
  {
    boot.initrd.systemd =
    {
      extraBin =
      {
        grep = "${pkgs.gnugrep}/bin/grep";
        awk = "${pkgs.gawk}/bin/awk";
        chattr = "${pkgs.e2fsprogs}/bin/chattr";
        lsmod = "${pkgs.kmod}/bin/lsmod";
      };
      services.roll-rootfs =
      {
        wantedBy = [ "initrd.target" ];
        after = [ "cryptsetup.target" "systemd-hibernate-resume.service" ];
        before = [ "local-fs-pre.target" "sysroot.mount" "create-needed-for-boot-dirs.service" ];
        unitConfig.DefaultDependencies = false;
        serviceConfig.Type = "oneshot";
        script = let inherit (config.fileSystems."/") device; in
          # TODO: snapshot should take place just before switching root
        ''
          # wait for device to be available
          while [ ! -b '${device}' ] || ! btrfs device ready '${device}'; do
            sleep 1
          done

          # mount device
          mount ${device} /mnt -m -o noatime

          # move old rootfs, create new one
          if [ -f /mnt/nix/rootfs/current/.timestamp ]; then
            timestamp=$(cat /mnt/nix/rootfs/current/.timestamp)
            subvolid=$(btrfs subvolume show /mnt/nix/rootfs/current | grep 'Subvolume ID:' | awk '{print $NF}')
            mv /mnt/nix/rootfs/current /mnt/nix/rootfs/$timestamp-$subvolid
            btrfs property set -ts /mnt/nix/rootfs/$timestamp-$subvolid ro true
          fi
          [ -d /mnt/nix/rootfs/current ] || btrfs subvolume create /mnt/nix/rootfs/current
          echo $(date '+%Y%m%d%H%M%S') > /mnt/nix/rootfs/current/.timestamp

          # make systemd happy
          mkdir -p /mnt/nix/rootfs/current/usr
          touch /mnt/nix/rootfs/current/usr/make-systemd-happy

          # backup persistent
          if [ -d /mnt/nix/persistent/.backups ]; then
            btrfs subvolume snapshot -r /mnt/nix/persistent \
              /mnt/nix/persistent/.backups/boot-$(date '+%Y%m%d%H%M%S')
          fi

          umount /mnt
        '';
      };
    };
  };
}
