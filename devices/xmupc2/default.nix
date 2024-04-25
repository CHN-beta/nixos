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
            vfat."/dev/disk/by-uuid/23CA-F4C4" = "/boot/efi";
            btrfs =
            {
              "/dev/disk/by-uuid/d187e03c-a2b6-455b-931a-8d35b529edac" =
                { "/nix/rootfs/current" = "/"; "/nix" = "/nix"; "/nix/boot" = "/boot"; };
            };
          };
          swap = [ "/nix/swap/swap" ];
          rollingRootfs = {};
        };
        grub.installDevice = "efi";
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
        nix.remote.slave.enable = true;
      };
      hardware = { cpus = [ "intel" ]; gpu.type = "nvidia"; };
      packages.packageSet = "workstation";
      virtualization = { waydroid.enable = true; docker.enable = true; kvmHost = { enable = true; gui = true; }; };
      services =
      {
        snapper.enable = true;
        fontconfig.enable = true;
        sshd = { passwordAuthentication = true; groupBanner = true; };
        xray.client.dae.wanInterface = [ "wlp4s0" ];
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
          cpu = { sockets = 2; cores = 22; threads = 2; };
          memoryMB = 253952;
          gpus = { "4090" = 1; "p5000" = 1; };
        };
        xrdp = { enable = true; hostname = [ "xmupc2.chn.moe" ]; };
        samba = { enable = true; hostsAllowed = ""; shares = { home.path = "/home"; root.path = "/"; }; };
        groupshare = {};
      };
      bugs = [ "xmunet" ];
      user.users = [ "chn" "xll" "zem" "yjq" "gb" ];
    };
  };
}
