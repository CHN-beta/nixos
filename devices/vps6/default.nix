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
              "/dev/disk/by-uuid/0067ef91-06f7-416e-88cb-4880ce04afa4"."/boot" = "/boot";
              "/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
            };
          };
          swap = [ "/nix/swap/swap" ];
          rollingRootfs = {};
        };
        grub.installDevice = "/dev/disk/by-path/pci-0000:00:05.0-scsi-0:0:0:0";
        nixpkgs.march = "znver2";
        nix.substituters = [ "https://nix-store.chn.moe?priority=100" ];
        initrd.sshd = {};
        networking = {};
        # do not use cachyos kernel, beesd + cachyos kernel + heavy io = system freeze, not sure why
      };
      services =
      {
        sshd = {};
        xray.server = { serverName = "vps6.xserver.chn.moe"; userNumber = 22; };
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
            [ "xn--s8w913fdga" "misskey" "synapse" "matrix" "send" "api" "git" "grafana" "peertube" ]));
          applications =
          {
            element.instances."element.chn.moe" = {};
            synapse-admin.instances."synapse-admin.chn.moe" = {};
            catalog.enable = true;
            main.enable = true;
            nekomia.enable = true;
            blog = {};
            sticker = {};
            tgapi = {};
          };
        };
        coturn = {};
        httpua = {};
        mirism.enable = true;
        fail2ban = {};
        beesd.instances.root = "/";
      };
    };
    specialisation.generic.configuration =
    {
      nixos.system.nixpkgs.march = inputs.lib.mkForce null;
      system.nixos.tags = [ "generic" ];
    };
  };
}
