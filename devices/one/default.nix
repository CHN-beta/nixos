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
        # recent kernel make touchscreen not work
        kernel.variant = "xanmod-lts";
      };
      hardware = { cpus = [ "intel" ]; gpu.type = "intel"; };
      services =
      {
        xray.client.enable = true;
        beesd.instances.root = { device = "/"; hashTableSizeMB = 512; };
        sshd = {};
      };
      virtualization.kvmHost = { enable = true; gui = true; };
      bugs = [ "xmunet" ];
    };
  };
}
