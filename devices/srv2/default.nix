inputs:
{
  config =
  {
    nixos =
    {
      model.type = "server";
      system =
      {
        fileSystems.mount = let inherit (inputs.config.nixos.model.cluster) clusterName nodeName; in
        {
          vfat."/dev/disk/by-partlabel/${clusterName}-${nodeName}-boot" = "/boot";
          btrfs."/dev/disk/by-partlabel/${clusterName}-${nodeName}-root1" =
            { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
          nfs."${inputs.topInputs.self.config.dns."chn.moe".getAddress "wg1.pc"}:/" =
            { mountPoint = "/nix/remote/pc"; hard = false; };
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
        sshd = {};
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
        mariadb.mountFrom = "nodatacow";
      };
      packages = { vasp = {}; desktop = {}; lumerical = {}; };
      user.users =
      [
        # 组内
        "chn" "xll" "zem" "yjq" "gb" "wp" "hjp" "wm" "qmx"
        # 组外
        "yxf" # 小芳同志
        "hss" # 还没见到本人
        "zzn" # 张宗南
        "zqq" # 庄芹芹
        "zgq" # 希望能接好班
        "lly" # 这谁？
      ];
    };
  };
}
