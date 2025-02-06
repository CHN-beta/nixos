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
          mount = let inherit (inputs.config.nixos.model.cluster) clusterName nodeName; in
          {
            vfat."/dev/disk/by-partlabel/${clusterName}-${nodeName}-boot" = "/boot";
            btrfs."/dev/disk/by-partlabel/${clusterName}-${nodeName}-root1" =
              { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
          };
          swap = [ "/nix/swap/swap" ];
          rollingRootfs = {};
        };
        nixpkgs.cuda =
        {
          enable = true;
          capabilities =
          [
            # p5000 p400
            "6.1"
            # 2080 Ti
            "7.5"
            # 3090
            "8.6"
            # 4090
            "8.9"
          ];
          forwardCompat = false;
        };
      };
      hardware.gpu = { type = "nvidia"; nvidia.open = false; };
      services =
      {
        sshd = { passwordAuthentication = true; groupBanner = true; };
        slurm =
        {
          enable = true;
          master = "srv2-node0";
          node =
          {
            srv2-node0 =
            {
              name = "n0"; address = "192.168.178.1";
              cpu = { sockets = 2; cores = 22; threads = 2; };
              memoryMB = 240 * 1024;
              gpus."4090" = 1;
            };
            srv2-node1 =
            {
              name = "n1"; address = "192.168.178.2";
              cpu = { cores = 16; threads = 2; };
              memoryMB = 80 * 1024;
              gpus = { "3090" = 1; "4090" = 1; };
            };
          };
          partitions =
          {
            all = [ "srv2-node0" "srv2-node1" ];
            n0 = [ "srv2-node0" ];
            n1 = [ "srv2-node1" ];
          };
          defaultPartition = "all";
          tui =
          {
            cpuQueues =
            [
              { name = "n0"; mpiThreads = 8; openmpThreads = 5; }
              { name = "n1"; mpiThreads = 3; openmpThreads = 4; }
            ];
            gpuIds = [ "4090" "3090" ];
            gpuPartition = "all";
          };
        };
      };
      user.users = [ "chn" "xll" "zem" "yjq" "gb" "wp" "hjp" "wm" "lly" "yxf" "hss" "zzn" ];
    };
  };
}
