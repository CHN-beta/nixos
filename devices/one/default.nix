inputs:
{
  config =
  {
    nixos =
    {
      model = { type = "desktop"; private = true; };
      system =
      {
        fileSystems =
        {
          mount =
          {
            vfat."/dev/disk/by-partlabel/one-boot" = "/boot";
            btrfs."/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
          };
          luks.auto."/dev/disk/by-partlabel/one-root" = { mapper = "root"; ssd = true; };
          swap = [ "/nix/swap/swap" ];
          resume = { device = "/dev/mapper/root"; offset = 4728064; };
          rollingRootfs = {};
        };
        nixpkgs.march = "tigerlake";
        kernel.variant = "cachyos";
      };
      hardware = { cpus = [ "intel" ]; gpu.type = "intel"; };
      services =
      {
        snapper.enable = true;
        xray.client.enable = true;
        smartd.enable = true;
        beesd.instances.root = { device = "/"; hashTableSizeMB = 512; };
        wireguard =
        {
          enable = true;
          peers = [ "vps6" ];
          publicKey = "Hey9V9lleafneEJwTLPaTV11wbzCQF34Cnhr0w2ihDQ=";
          wireguardIp = "192.168.83.5";
        };
        sshd = {};
      };
      bugs = [ "xmunet" ];
    };
  };
}
