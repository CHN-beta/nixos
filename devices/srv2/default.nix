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
            nfs."${inputs.topInputs.self.config.dns."chn.moe".getAddress "wg1.pc"}:/" =
              { mountPoint = "/nix/remote/pc"; hard = false; };
          };
          swap = [ "/nix/swap/swap" ];
          rollingRootfs = {};
        };
        nixpkgs.cuda.capabilities =
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
      };
      hardware.gpu.type = "nvidia";
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
              memoryGB = 240;
              gpus."4090" = 1;
            };
            srv2-node1 =
            {
              name = "n1"; address = "192.168.178.2";
              cpu = { sockets = 2; cores = 8; threads = 2; };
              memoryGB = 80;
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
              { name = "n0"; mpiThreads = 8; openmpThreads = 5; memoryGB = 216; allocateCpus = 43; }
              { name = "n1"; mpiThreads = 4; openmpThreads = 3; memoryGB = 32; allocateCpus = 12; }
            ];
            gpuQueues =
            [
              { name = "all"; gpuIds = [ "4090" "3090" ]; }
              { name = "n0"; gpuIds = [ "4090" ]; }
              { name = "n1"; gpuIds = [ "3090" "4090" ]; }
            ];
          };
        };
      };
      packages = { vasp = {}; mumax = {}; };
      user.users = [ "chn" "xll" "zem" "yjq" "gb" "wp" "hjp" "wm" "lly" "yxf" "hss" "zzn" ];
    };
  };
}
