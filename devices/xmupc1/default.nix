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
            # TODO: reparition
            vfat."/dev/disk/by-uuid/467C-02E3" = "/boot";
            btrfs =
            {
              "/dev/disk/by-uuid/2f9060bc-09b5-4348-ad0f-3a43a91d158b"."/nix" = "/nix";
              "/dev/disk/by-uuid/a04a1fb0-e4ed-4c91-9846-2f9e716f6e12" =
              {
                "/nix/rootfs" = "/nix/rootfs";
                "/nix/persistent" = "/nix/persistent";
                "/nix/nodatacow" = "/nix/nodatacow";
                "/nix/rootfs/current" = "/";
              };
            };
          };
          swap = [ "/nix/swap/swap" ];
          rollingRootfs = {};
        };
        nixpkgs =
        {
          march = "znver3";
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
        networking.hostname = "xmupc1";
        nix.remote.slave.enable = true;
      };
      hardware = { cpus = [ "amd" ]; gpu.type = "nvidia"; };
      virtualization = { waydroid.enable = true; docker.enable = true; kvmHost = { enable = true; gui = true; }; };
      services =
      {
        snapper.enable = true;
        sshd = { passwordAuthentication = true; groupBanner = true; };
        xray.client.enable = true;
        firewall.trustedInterfaces = [ "virbr0" "waydroid0" ];
        smartd.enable = true;
        beesd.instances =
        {
          root = { device = "/"; hashTableSizeMB = 16384; threads = 4; };
          nix = { device = "/nix"; hashTableSizeMB = 512; };
        };
        wireguard =
        {
          enable = true;
          peers = [ "vps6" ];
          publicKey = "JEY7D4ANfTpevjXNvGDYO6aGwtBGRXsf/iwNwjwDRQk=";
          wireguardIp = "192.168.83.6";
        };
        slurm =
        {
          enable = true;
          cpu = { cores = 16; threads = 2; mpiThreads = 3; openmpThreads = 4; };
          memoryMB = 94208;
          gpus = { "2080_ti" = 1; "3090" = 1; "4090" = 1; };
        };
        xrdp = { enable = true; hostname = [ "xmupc1.chn.moe" ]; };
        samba =
        {
          enable = true;
          hostsAllowed = "";
          shares = { home.path = "/home"; root.path = "/"; };
        };
        groupshare = {};
        hpcstat = {};
      };
      bugs = [ "xmunet" "amdpstate" ];
      user.users = [ "chn" "xll" "zem" "yjq" "gb" "wp" "hjp" ];
    };
    services.hardware.bolt.enable = true;
  };
}
