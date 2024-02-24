inputs:
{
  config =
  {
    nixos =
    {
      system =
      {
        fileSystems =
        {
          mount =
          {
            btrfs =
            {
              "/dev/disk/by-uuid/24577c0e-d56b-45ba-8b36-95a848228600"."/boot" = "/boot";
              "/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
            };
          };
          decrypt.manual =
          {
            enable = true;
            devices."/dev/disk/by-uuid/4f8aca22-9ec6-4fad-b21a-fd9d8d0514e8" = { mapper = "root"; ssd = true; };
            delayedMount = [ "/" ];
          };
          swap = [ "/nix/swap/swap" ];
          rollingRootfs = { device = "/dev/mapper/root"; path = "/nix/rootfs"; };
        };
        grub.installDevice = "/dev/disk/by-path/pci-0000:00:05.0-scsi-0:0:0:0";
        nixpkgs.march = "sandybridge";
        nix.substituters = [ "https://cache.nixos.org/" "https://nix-store.chn.moe" ];
        initrd.sshd.enable = true;
        networking.hostname = "vps6";
      };
      packages.packageSet = "server";
      services =
      {
        snapper.enable = false;
        sshd.enable = true;
        xray.server = { enable = true; serverName = "vps6.xserver.chn.moe"; };
        frpServer = { enable = true; serverName = "frp.chn.moe"; };
        nginx =
        {
          streamProxy.map =
          {
            "anchor.fm" = { upstream = "anchor.fm:443"; proxyProtocol = false; };
            "podcasters.spotify.com" = { upstream = "podcasters.spotify.com:443"; proxyProtocol = false; };
            "xlog.chn.moe" = { upstream = "cname.xlog.app:443"; proxyProtocol = false; };
          }
          // (builtins.listToAttrs (builtins.map
            (site: { name = "${site}.chn.moe"; value.upstream.address = "wireguard.pc.chn.moe"; })
            [ "nix-store" "xn--qbtm095lrg0bfka60z" ]))
          // (builtins.listToAttrs (builtins.map
            (site: { name = "${site}.chn.moe"; value.upstream.address = "wireguard.vps7.chn.moe"; })
            [
              "xn--s8w913fdga" "misskey" "synapse" "syncv3.synapse" "matrix" "syncv3.matrix"
              "send" "kkmeeting" "api" "git" "grafana" "vikunja"
            ]));
          applications =
          {
            element.instances."element.chn.moe" = {};
            synapse-admin.instances."synapse-admin.chn.moe" = {};
            catalog.enable = true;
            blog.enable = true;
            main.enable = true;
          };
        };
        coturn.enable = true;
        httpua.enable = true;
        mirism.enable = true;
        fail2ban.enable = true;
        wireguard =
        {
          enable = true;
          peers = [ "pc" "nas" "vps7" "surface" ];
          publicKey = "AVOsYUKQQCvo3ctst3vNi8XSVWo1Wh15066aHh+KpF4=";
          wireguardIp = "192.168.83.1";
          listenIp = "74.211.99.69";
          lighthouse = true;
        };
        beesd = { enable = true; instances.root = { device = "/"; hashTableSizeMB = 64; }; };
      };
    };
  };
}
