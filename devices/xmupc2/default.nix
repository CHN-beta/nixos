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
        networking.hostname = "xmupc2";
        nix =
        {
          marches =
          [
            "broadwell" "skylake"
            # AVX512F CLWB AVX512VL AVX512BW AVX512DQ AVX512CD AVX512VNNI
            # "cascadelake"
          ];
          remote.slave.enable = true;
          substituters = [ "https://nix-store.chn.moe?priority=100" ];
        };
        grub.windowsEntries."8F50-83B8" = "猿神，启动！";
      };
      hardware = { cpus = [ "intel" ]; gpu.type = "nvidia"; };
      virtualization = { waydroid.enable = true; docker.enable = true; kvmHost = { enable = true; gui = true; }; };
      services =
      {
        snapper.enable = true;
        sshd = { passwordAuthentication = true; groupBanner = true; };
        xray.client.enable = true;
        firewall.trustedInterfaces = [ "virbr0" "waydroid0" ];
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
          cpu = { sockets = 2; cores = 22; threads = 2; mpiThreads = 4; openmpThreads = 10; };
          memoryMB = 253952;
          gpus."4090" = 1;
        };
        xrdp = { enable = true; hostname = [ "xmupc2.chn.moe" ]; };
        samba = { enable = true; hostsAllowed = ""; shares = { home.path = "/home"; root.path = "/"; }; };
        groupshare = {};
      };
      bugs = [ "xmunet" ];
      user.users = [ "chn" "xll" "zem" "yjq" "gb" "wp" "hjp" "wm" ];
    };
  };
}
