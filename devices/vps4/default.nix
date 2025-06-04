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
              "/dev/disk/by-uuid/403fe853-8648-4c16-b2b5-3dfa88aee351"."/boot" = "/boot";
              "/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
            };
          };
          swap = [ "/nix/swap/swap" ];
          rollingRootfs = {};
        };
        grub.installDevice = "/dev/disk/by-path/pci-0000:00:04.0";
        nixpkgs.march = "znver2";
        initrd.sshd = {};
        network = {};
      };
      services =
      {
        sshd = {};
        fail2ban = {};
        xray.server.serverName = "xserver.vps4.chn.moe";
      };
    };
    networking.nftables.tables.forward =
    {
      family = "inet";
      content = let srv2 = inputs.topInputs.self.config.dns."chn.moe".getAddress "wg1.srv2-node0"; in
      ''
        chain prerouting {
          type nat hook prerouting priority dstnat; policy accept;
          tcp dport 7011 fib daddr type local counter meta mark set meta mark | 4 dnat ip to ${srv2}:22
        }
        chain output {
          type nat hook output priority dstnat; policy accept;
          tcp dport 7011 fib daddr type local counter meta mark set meta mark | 4 dnat ip to ${srv2}:22
        }
        chain postrouting {
          type nat hook postrouting priority srcnat; policy accept;
          oifname wg1 meta mark & 4 == 4 counter masquerade
        }
      '';
    };
  };
}
