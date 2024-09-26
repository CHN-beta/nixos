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
            vfat."/dev/disk/by-uuid/627D-1FAA" = "/boot";
            btrfs =
            {
              "/dev/mapper/nix"."/nix" = "/nix";
              "/dev/mapper/root3" =
              {
                "/nix/rootfs" = "/nix/rootfs";
                "/nix/persistent" = "/nix/persistent";
                "/nix/nodatacow" = "/nix/nodatacow";
                "/nix/rootfs/current" = "/";
                "/nix/backup" = "/nix/backup";
              };
            };
          };
          luks.manual =
          {
            enable = true;
            devices =
            {
              "/dev/disk/by-uuid/a47f06e1-dc90-40a4-89ea-7c74226a5449".mapper = "root3";
              "/dev/disk/by-uuid/b3408fb5-68de-405b-9587-5e6fbd459ea2".mapper = "root4";
              "/dev/disk/by-uuid/a779198f-cce9-4c3d-a64a-9ec45f6f5495" = { mapper = "nix"; ssd = true; };
            };
            delayedMount = [ "/" "/nix" ];
          };
          swap = [ "/nix/swap/swap" ];
          rollingRootfs.waitDevices = [ "/dev/mapper/root4" ];
        };
        initrd.sshd.enable = true;
        nixpkgs.march = "silvermont";
        nix.substituters = [ "https://nix-store.chn.moe?priority=100" ];
        networking.networkd = {};
      };
      hardware = { cpus = [ "intel" ]; gpu.type = "intel"; };
      services =
      {
        snapper.enable = true;
        sshd = {};
        xray.client = { enable = true; dnsmasq.hosts."git.nas.chn.moe" = "127.0.0.1"; };
        smartd.enable = true;
        beesd.instances =
        {
          root = { device = "/"; hashTableSizeMB = 4096; threads = 4; };
          nix = { device = "/nix"; hashTableSizeMB = 128; };
        };
        wireguard =
        {
          enable = true;
          peers = [ "vps6" ];
          publicKey = "xCYRbZEaGloMk7Awr00UR3JcDJy4AzVp4QvGNoyEgFY=";
          wireguardIp = "192.168.83.4";
        };
      };
    };
  };
}
