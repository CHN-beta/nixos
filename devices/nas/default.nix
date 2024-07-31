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
            vfat."/dev/disk/by-uuid/13BC-F0C9" = "/boot/efi";
            btrfs =
            {
              "/dev/disk/by-uuid/0e184f3b-af6c-4f5d-926a-2559f2dc3063"."/boot" = "/boot";
              "/dev/mapper/nix"."/nix" = "/nix";
              "/dev/mapper/root1" =
              {
                "/nix/rootfs" = "/nix/rootfs";
                "/nix/persistent" = "/nix/persistent";
                "/nix/nodatacow" = "/nix/nodatacow";
                "/nix/rootfs/current" = "/";
                "/nix/backup" = "/nix/backup";
              };
            };
          };
          decrypt.manual =
          {
            enable = true;
            devices =
            {
              "/dev/disk/by-uuid/5cf1d19d-b4a5-4e67-8e10-f63f0d5bb649".mapper = "root1";
              "/dev/disk/by-uuid/aa684baf-fd8a-459c-99ba-11eb7636cb0d".mapper = "root2";
              "/dev/disk/by-uuid/a47f06e1-dc90-40a4-89ea-7c74226a5449".mapper = "root3";
              "/dev/disk/by-uuid/b3408fb5-68de-405b-9587-5e6fbd459ea2".mapper = "root4";
              "/dev/disk/by-uuid/a779198f-cce9-4c3d-a64a-9ec45f6f5495" = { mapper = "nix"; ssd = true; };
            };
            delayedMount = [ "/" "/nix" ];
          };
          swap = [ "/nix/swap/swap" ];
          rollingRootfs.waitDevices = [ "/dev/mapper/root2" "/dev/mapper/root3" "/dev/mapper/root4" ];
        };
        initrd.sshd.enable = true;
        grub.installDevice = "efi";
        nixpkgs.march = "silvermont";
        nix.substituters = [ "https://cache.nixos.org/" "https://nix-store.chn.moe" ];
        networking = { hostname = "nas"; networkd = {}; };
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
