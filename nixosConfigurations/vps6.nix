{ config, pkgs, ... }:
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
          luks."/dev/disk/by-uuid/961d75f0-b4ad-4591-a225-37b385131060" = { mapper = "root"; ssd = true; };
        };
        grub.installDevice = "/dev/disk/by-path/pci-0000:00:05.0-scsi-0:0:0:0";
        nixpkgs.march = "znver2";
        initrd.sshd = {};
      };
      services =
      {
        sshd = {};
        nginx.applications =
        {
          element = {};
          synapse-admin = {};
          catalog = {};
          main = {};
          nekomia = {};
          blog = {};
          sticker = {};
          tgapi = {};
          short = {};
        };
        coturn = {};
        httpua = {};
        mirism = {};
        fail2ban = {};
        beesd."/" = {};
        coredns = { interface = "ens18"; ns = "vps6.chn.moe"; };
        headscale = {};
        missgram = {};
        hongbao = {};
        vikunja = {};
      };
    };
    networking.nftables.tables.forward =
    {
      family = "inet";
      content = let srv2 = pkgs.localPkgs.getAddress "tinc0.srv2-node0"; pc = pkgs.localPkgs.getAddress "tinc0.pc"; in
      ''
        chain prerouting {
          type nat hook prerouting priority dstnat; policy accept;
          tcp dport 7011 fib daddr type local counter meta mark set meta mark | 4 dnat ip to ${srv2}:22
          tcp dport 7012 fib daddr type local counter meta mark set meta mark | 4 dnat ip to ${pc}:22
        }
        chain output {
          type nat hook output priority dstnat; policy accept;
          # 需要忽略透明代理发出的流量（gid 不是 nginx）
          meta skgid != ${builtins.toString config.users.groups.nginx.gid} \
            tcp dport 7011 fib daddr type local \
            counter meta mark set meta mark | 4 dnat ip to ${srv2}:22
          meta skgid != ${builtins.toString config.users.groups.nginx.gid} \
            tcp dport 7012 fib daddr type local \
            counter meta mark set meta mark | 4 dnat ip to ${pc}:22
        }
        chain postrouting {
          type nat hook postrouting priority srcnat; policy accept;
          oifname tinc0 meta mark & 4 == 4 counter masquerade
        }
      '';
    };
  };
}
