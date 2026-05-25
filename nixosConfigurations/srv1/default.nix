{ config, pkgs, ... }:
{
  config =
  {
    nixos =
    {
      model.variant = "server";
      system =
      {
        fileSystems =
        {
          mount = let inherit (config.nixos.model.cluster) clusterName nodeName; in
          {
            vfat."/dev/disk/by-partlabel/${clusterName}-${nodeName}-boot" = "/boot";
            btrfs."/dev/disk/by-partlabel/${clusterName}-${nodeName}-root" =
              { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
          };
          swap = [ "/nix/swap/swap" ];
        };
      };
      services =
      {
        sshd.passwordAuthentication = true;
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
              memoryGB = 112;
            };
            srv1-node1 =
            {
              name = "n1"; address = "192.168.178.2";
              cpu = { sockets = 4; cores = 8; threads = 2; };
              memoryGB = 112;
            };
            srv1-node2 =
            {
              name = "n2"; address = "192.168.178.3";
              cpu = { sockets = 4; cores = 8; threads = 2; };
              memoryGB = 56;
            };
          };
          partitions =
          {
            n0 = [ "srv1-node0" ];
            n1 = [ "srv1-node1" ];
            n2 = [ "srv1-node2" ];
            all = [ "srv1-node0" "srv1-node1" "srv1-node2" ];
          };
          tui.cpuQueues =
          [
            { name = "n0"; mpiThreads = 8; openmpThreads = 10; }
            { name = "n1"; mpiThreads = 8; openmpThreads = 4; }
          ];
        };
        mariadb.mountFrom = "nodatacow";
      };
      packages = { vasp = {}; lumerical = {}; };
      user.users = [ "chn" "xll" "zem" "yjq" "gb" "wp" "hjp" "wm" "GROUPIII-1" "GROUPIII-2" "GROUPIII-3" "zgq" "qmx" ];
    };
  };
}
