{ lib, ... }:
{
  imports = lib.findModules ./.;
  config = {
    nixos = {
      model.private = true;
      system = {
        fileSystems = {
          mount = {
            vfat."/dev/disk/by-partlabel/nas-boot" = "/boot";
            btrfs = {
              "/dev/lvm/root1" = {
                "/nix" = "/nix";
                "/nix/rootfs/current" = "/";
                "/" = "/nix/export";
              };
              "/dev/lvm/ssd1"."/nix/ssd" = "/nix/ssd";
              "/dev/lvm/single1"."/nix" = "/nix/backup/nix";
            };
          };
          swap = [ "/dev/lvm/swap" ];
          luks = {
            devices = {
              "/dev/disk/by-partlabel/nas-root1".mapper = "root1";
              "/dev/disk/by-partlabel/nas-root2".mapper = "root2";
              "/dev/disk/by-partlabel/nas-root3" = {
                mapper = "root3";
                ssd = true;
              };
              "/dev/disk/by-partlabel/nas-root4" = {
                mapper = "root4";
                ssd = true;
              };
            };
            enablePkcs11 = false;
          };
          backup = {
            persistent = {
              device = "/dev/lvm/root1";
              subvol = "/nix/persistent";
            };
            ssd = {
              device = "/dev/lvm/ssd1";
              subvol = "/nix/ssd";
            };
          };
        };
        initrd.sshd = { };
        nixpkgs.march = "alderlake";
        kernel.patches = [ "btrfs" ];
        binfmt = { };
      };
      hardware = {
        gpu.type = [ "intel" ];
        ugreen = { };
      };
      services = {
        sshd = { };
        xray.client.coredns = {
          extraInterfaces = [ "enp3s0" ];
          hosts."git.chn.moe" = "127.0.0.1";
        };
        beesd = {
          "/".hashTableSizeMB = 10 * 128;
          "/nix/backup/nix".hashTableSizeMB = 3 * 128;
        };
        postgresql.mountFrom = "ssd";
        mariadb.mountFrom = "ssd";
        rsshub = { };
        misskey.instances = {
          misskey.hostname = "xn--s8w913fdga.chn.moe";
          misskey-old = {
            port = 9727;
            redis.port = 3546;
          };
        };
        synapse.instances = {
          synapse.matrixHostname = "synapse.chn.moe";
          matrix = {
            port = 8009;
            redisPort = 6380;
          };
        };
        vaultwarden = { };
        nextcloud = { };
        freshrss = { };
        send = { };
        huginn = { };
        httpapi = { };
        podman = { };
        peertube = { };
        nginx.applications.webdav.instances."webdav.chn.moe" = { };
        nfs = {
          exports."/nix/export" = [ "100.97.101.0/24" ];
          crossmnt = false;
        };
        immich = { };
        minibox = { };
        harmonia = {
          hostname = "backup-store.chn.moe";
          store = "/nix/backup";
        };
        snapper = {
          persistent = "/nix/persistent";
          ssd = "/nix/ssd";
        };
        github-runners = { };
        pppoe.interface = "enp3s0";
        antigravity-route = { };
      };
      packages.opencode = { };
    };
    systemd.tmpfiles.rules = [
      "w /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_0_power_limit_uw - - - - 10000000"
    ];
  };
}
