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
            vfat."/dev/disk/by-uuid/7A60-4232" = "/boot";
            btrfs."/dev/mapper/root1" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
          };
          swap = [ "/dev/mapper/swap" ];
          rollingRootfs = {};
        };
        nixpkgs.march = "cascadelake";
        kernel.variant = "xanmod-lts";
        networking.hostname = "srv1-node0";
        gui.enable = true;
      };
      hardware.cpus = [ "intel" ];
      services =
      {
        snapper.enable = true;
        sshd = {};
        xray.client.enable = true;
        smartd.enable = true;
        beesd.instances.root = { device = "/"; hashTableSizeMB = 4096; threads = 4; };
        wireguard =
        {
          enable = true;
          peers = [ "vps6" ];
          publicKey = "l1gFSDCeBxyf/BipXNvoEvVvLqPgdil84nmr5q6+EEw=";
          wireguardIp = "192.168.83.3";
        };
        slurm =
        {
          enable = true;
          cpu = { cores = 16; threads = 2; mpiThreads = 2; openmpThreads = 4; };
          memoryMB = 90112;
        };
      };
      user.users = [ "chn" ];
    };
  };
}
