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
            vfat."/dev/disk/by-uuid/23CA-F4C4" = "/boot";
            btrfs =
            {
              "/dev/disk/by-uuid/d187e03c-a2b6-455b-931a-8d35b529edac" =
                { "/nix/rootfs/current" = "/"; "/nix" = "/nix"; };
            };
          };
          swap = [ "/nix/swap/swap" ];
          rollingRootfs = {};
        };
        nixpkgs =
        {
          march = "skylake";
          cuda =
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
        gui = { enable = true; preferred = false; autoStart = true; };
        nix =
        {
          marches =
          [
            "broadwell" "skylake"
            # AVX512F CLWB AVX512VL AVX512BW AVX512DQ AVX512CD AVX512VNNI
            # "cascadelake"
          ];
          remote.slave.enable = true;
        };
        grub.windowsEntries."8F50-83B8" = "猿神，启动！";
      };
      hardware = { cpus = [ "intel" ]; gpu.type = "nvidia"; };
      virtualization.kvmHost = { enable = true; gui = true; };
      services =
      {
        snapper.enable = true;
        sshd = { passwordAuthentication = true; groupBanner = true; };
        xray.client.enable = true;
        smartd.enable = true;
        beesd.instances.root = { device = "/"; hashTableSizeMB = 16384; threads = 4; };
        wireguard =
        {
          enable = true;
          peers = [ "vps6" ];
          publicKey = "lNTwQqaR0w/loeG3Fh5qzQevuAVXhKXgiPt6fZoBGFE=";
          wireguardIp = "192.168.83.7";
        };
        slurm =
        {
          enable = true;
          master = "xmupc2";
          node.xmupc2 =
          {
            name = "xmupc2"; address = "127.0.0.1";
            cpu = { sockets = 2; cores = 22; threads = 2; };
            memoryMB = 253952;
            gpus."4090" = 1;
          };
          partitions.localhost = [ "xmupc2" ];
          tui = { cpuMpiThreads = 8; cpuOpenmpThreads = 10; gpus = [ "4090" ]; };
        };
        xrdp = { enable = true; hostname = [ "xmupc2.chn.moe" ]; };
        samba = { enable = true; hostsAllowed = ""; shares = { home.path = "/home"; root.path = "/"; }; };
        groupshare = {};
        docker = {};
      };
      bugs = [ "xmunet" ];
      user.users = [ "chn" "xll" "zem" "yjq" "gb" "wp" "hjp" "wm" ];
    };
  };
}
