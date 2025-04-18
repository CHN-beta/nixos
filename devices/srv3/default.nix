inputs:
{
  config =
  {
    nixos =
    {
      model.type = "server";
      system =
      {
        fileSystems =
        {
          mount =
          {
            vfat."/dev/disk/by-partlabel/srv3-boot" = "/boot";
            btrfs."/dev/mapper/root1" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
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
