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
        };
        grub.installDevice = "/dev/disk/by-path/pci-0000:00:05.0-scsi-0:0:0:0";
        nixpkgs.march = "znver2";
        initrd.sshd = {};
        network = {};
      };
      services =
      {
        sshd = {};
        xray = { server = {}; xmuPersist = {}; };
        nginx =
        {
          streamProxy.map =
          {
            "anchor.fm" = { upstream = "anchor.fm:443"; proxyProtocol = false; };
            "podcasters.spotify.com" = { upstream = "podcasters.spotify.com:443"; proxyProtocol = false; };
            "xlog.chn.moe" = { upstream = "cname.xlog.app:443"; proxyProtocol = false; };
            "xservernas.chn.moe" = { upstream = "wg0.nas.chn.moe:443"; proxyProtocol = false; };
          }
          // (builtins.listToAttrs (builtins.map
            (site: { name = "${site}.chn.moe"; value.upstream.address = "wg0.pc.chn.moe"; })
            [ "xn--qbtm095lrg0bfka60z" ]))
          // (builtins.listToAttrs (builtins.map
            (site: { name = "${site}.chn.moe"; value.upstream.address = "wg0.nas.chn.moe"; })
            [
              "xn--s8w913fdga" "matrix" "send" "git" "grafana" "peertube" "rsshub" "misskey" "synapse" "vaultwarden"
              "photoprism" "nextcloud" "freshrss" "huginn" "api" "webdav" "chat"
            ]));
          applications =
          {
            element.instances."element.chn.moe" = {};
            synapse-admin.instances."synapse-admin.chn.moe" = {};
            catalog.enable = true;
            main = {};
            nekomia.enable = true;
            blog = {};
            sticker = {};
            tgapi = {};
          };
        };
        coturn = {};
        httpua = {};
        mirism = {};
        fail2ban = {};
        beesd."/" = {};
        # bind = {};
      };
    };
    networking.nftables.tables.forward =
    {
      family = "inet";
      content =
        let
          srv2 = inputs.topInputs.self.config.dns."chn.moe".getAddress "wg0.srv2-node0";
          nas = inputs.topInputs.self.config.dns."chn.moe".getAddress "wg0.nas";
        in
        ''
          chain prerouting {
            type nat hook prerouting priority dstnat; policy accept;
            tcp dport 7011 fib daddr type local counter meta mark set meta mark | 4 dnat ip to ${srv2}:22
            tcp dport 7012 fib daddr type local counter meta mark set meta mark | 4 dnat ip to ${nas}:22
          }
          chain output {
            type nat hook output priority dstnat; policy accept;
            # 需要忽略透明代理发出的流量（gid 不是 nginx）
            meta skgid != ${builtins.toString inputs.config.users.groups.nginx.gid} \
              tcp dport 7011 fib daddr type local \
              counter meta mark set meta mark | 4 dnat ip to ${srv2}:22
            meta skgid != ${builtins.toString inputs.config.users.groups.nginx.gid} \
              tcp dport 7012 fib daddr type local \
              counter meta mark set meta mark | 4 dnat ip to ${nas}:22
          }
          chain postrouting {
            type nat hook postrouting priority srcnat; policy accept;
            oifname wg0 meta mark & 4 == 4 counter masquerade
          }
        '';
    };
  };
}
