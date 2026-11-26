{ lib, pkgs, ... }:
{
  imports = lib.findModules ./.;
  config = {
    nixos = {
      model = {
        private = true;
        variant = "desktop";
      };
      system = {
        fileSystems = {
          mount = {
            vfat."/dev/disk/by-partlabel/nas-boot" = "/boot";
            btrfs = {
              "/dev/lvm/root1" = {
                "/nix/rootfs" = "/nix/rootfs";
                "/nix/backup" = "/nix/backup";
                "/nix/nodatacow" = "/nix/nodatacow";
                "/nix/persistent" = "/nix/persistent";
                "/nix/rootfs/current" = "/";
                "/" = "/nix/export";
                "/nix/remote/pc" = "/nix/remote/pc";
                "/nix/remote/xmuhk" = "/public/home/xmuhk";
                "/nix/remote/jykang" = "/data/gpfs01/jykang";
                "/nix/remote/wlin" = "/data/gpfs01/wlin";
                "/nix/remote/hwang" = "/data/gpfs01/hwang";
              };
              "/dev/lvm/ssd2"."/nix" = "/nix";
            };
          };
          swap = [ "/dev/lvm/swap" ];
          luks = {
            devices = {
              "/dev/disk/by-partlabel/nas-root1".mapper = "root1";
              "/dev/disk/by-partlabel/nas-root2".mapper = "root2";
              "/dev/disk/by-partlabel/nas-root4" = {
                mapper = "root4";
                ssd = true;
              };
              "/dev/disk/by-partlabel/nas-root5" = {
                mapper = "root5";
                ssd = true;
              };
              "/dev/disk/by-partlabel/nas-root6".mapper = "root6";
            };
            enablePkcs11 = false;
          };
          backup = {
            persistent = {
              device = "/dev/lvm/root1";
              subvol = "/nix/persistent";
            };
            ssd = {
              device = "/dev/lvm/ssd2";
              subvol = "/nix/ssd";
            };
          };
        };
        initrd.sshd = { };
        nixpkgs = {
          march = "znver4";
          rocm.targets = [ "gfx1103" ];
        };
        kernel = {
          patches = [ "btrfs" ];
          variant = "nixos";
        };
        binfmt = { };
        network.implementation = "systemd-networkd";
      };
      hardware.gpu.type = [ "amd" ];
      services = {
        sshd = { };
        xray.client.coredns = {
          extraInterfaces = [ "enp3s0.20" ];
          hosts."git.chn.moe" = "127.0.0.1";
        };
        beesd."/" = {
          threads = 4;
          hashTableSizeMB = 10 * 128;
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
        # send = { };
        httpapi = { };
        podman = { };
        peertube = { };
        nginx.applications.webdav.instances."webdav.chn.moe" = { };
        nfs = {
          exports = {
            "/nix/export" = [ "100.97.101.0/24" ];
            "/nix/remote/pc" = {
              clients = [ "100.97.101.0/24" ];
              options = [
                "rw"
                "async"
                "no_subtree_check"
                "root_squash"
                "sec=sys"
                "fsid=8c7e4d12-5a3b-4e91-b2d4-9f0c1a6e3b85"
              ];
            };
          };
          crossmnt = false;
        };
        immich = { };
        bge-m3 = {
          hostname = "bgem3.chn.moe";
          gpu = false;
        };
        minibox = { };
        snapper = {
          persistent = "/nix/persistent";
          ssd = "/nix/ssd";
        };
        pppoe.interface = "enp2s0";
        cliproxyapi.users = [ "chn" ];
      };
      packages = {
        omp.users = [ "chn" ];
      };
      user.users = [
        "chn"
      ];
    };
    environment.systemPackages = with pkgs; [
      localPkgs.matlab
      xvfb-run
    ];
    services.udev.extraHwdb = ''
      # 交换键盘按键
      evdev:input:b*v*p*e*
       KEYBOARD_KEY_70039=leftmeta
       KEYBOARD_KEY_700e3=capslock
    '';
  };
}
