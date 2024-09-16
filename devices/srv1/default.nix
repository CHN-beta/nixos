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
          mount = let inherit (inputs.config.nixos.system.cluster) clusterName nodeName; in
          {
            vfat."/dev/disk/by-partlabel/${clusterName}-${nodeName}-boot" = "/boot";
            btrfs."/dev/disk/by-partlabel/${clusterName}-${nodeName}-root" =
              { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
          };
          swap = [ "/nix/swap/swap" ];
          rollingRootfs = {};
        };
        kernel.variant = "xanmod-lts";
        gui.enable = true;
      };
      hardware.cpus = [ "intel" ];
      services =
      {
        snapper.enable = true;
        sshd = {};
        smartd.enable = true;
        slurm =
        {
          enable = true;
          master = "srv1-node0";
          node =
          {
            srv1-node0 =
            {
              name = "n0"; address = "192.168.178.1";
              cpu = { sockets = 4; cores = 20; threads = 2; };
              memoryMB = 122880;
            };
            srv1-node1 =
            {
              name = "n1"; address = "192.168.178.2";
              cpu = { sockets = 4; cores = 8; threads = 2; };
              memoryMB = 30720;
            };
          };
          partitions =
          {
            default = [ "srv1-node0" ];
            old = [ "srv1-node1" ];
          };
        };
      };
      user.users = [ "chn" ];
    };
  };
}
