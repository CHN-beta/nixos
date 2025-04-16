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
            vfat."/dev/disk/by-partlabel/srv3-boot" = "/boot";
            btrfs."/dev/mapper/root1" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
          };
          luks.auto =
          {
            "/dev/disk/by-partlabel/srv3-root1" = { mapper = "root1"; ssd = true; };
            "/dev/disk/by-partlabel/srv3-root2" = { mapper = "root2"; ssd = true; };
            "/dev/disk/by-partlabel/srv3-swap" = { mapper = "swap"; ssd = true; };
          };
          swap = [ "/dev/mapper/swap" ];
          rollingRootfs = {};
        };
        nixpkgs.march = "haswell";
        kernel.variant = "cachyos-lts";
      };
      hardware.cpus = [ "intel" ];
      services =
      {
        beesd."/".hashTableSizeMB = 128;
        sshd = {};
      };
      virtualization.kvmHost = { enable = true; gui = true; };
    };
  };
}
