{ config, ... }:
{
  config = {
    fileSystems."/var/cache/fscache" = {
      device = "/dev/lvm/fscache";
      fsType = "ext4";
      neededForBoot = false;
      options = [
        "rw"
        "relatime"
        "lazytime"
        "user_xattr"
        "discard"
        "nofail"
      ];
    };
    services.cachefilesd = {
      enable = true;
      cacheDir = "/var/cache/fscache";
      extraConfig = ''
        tag nasgames
        culltable 14
        brun 8%
        bcull 5%
        bstop 2%
        frun 10%
        fcull 7%
        fstop 3%
      '';
    };
    systemd.services.cachefilesd.unitConfig.RequiresMountsFor = [
      config.services.cachefilesd.cacheDir
    ];
    nixos.system.fileSystems.mount.nfs."nas.ts.chn.moe:/nix/remote/pc" = {
      mountPoint = "/nix/remote/nas-games";
      automount = true;
      readOnly = false;
      fscache = true;
      actimeo = 60;
      extraOptions = [
        "nfsvers=4.2"
        "rsize=1048576"
        "wsize=1048576"
        "nconnect=4"
        "hard"
        "timeo=150"
        "retrans=3"
      ];
    };
  };
}
