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
        initrd.sshd = {};
        networking.static.eno1 =
        {
          ip = "23.135.236.216";
          mask = 24;
          gateway = "23.135.236.1";
          dns = "8.8.8.8";
        };
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
