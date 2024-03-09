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
          rollingRootfs.device = "/dev/disk/by-uuid/d187e03c-a2b6-455b-931a-8d35b529edac";
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
        gui = { preferred = false; autoStart = true; };
        kernel.patches = [ "cjktty" "lantian" ];
        networking.hostname = "xmupc2";
      };
      hardware =
      {
        cpus = [ "intel" ];
        gpu.type = "nvidia";
        bluetooth.enable = true;
        joystick.enable = true;
        printer.enable = true;
        sound.enable = true;
      };
      packages.packageSet = "workstation";
      virtualization = { waydroid.enable = true; docker.enable = true; kvmHost = { enable = true; gui = true; }; };
      services =
      {
        snapper.enable = false;
        fontconfig.enable = true;
        sshd = { enable = true; passwordAuthentication = true; };
        xray.client =
        {
          enable = true;
          serverAddress = "74.211.99.69";
          serverName = "vps6.xserver.chn.moe";
          dns.extraInterfaces = [ "docker0" ];
        };
        firewall.trustedInterfaces = [ "virbr0" "waydroid0" ];
        smartd.enable = true;
        beesd =
        {
          enable = false;
          instances.root = { device = "/"; hashTableSizeMB = 16384; threads = 4; };
        };
        wireguard =
        {
          enable = true;
          peers = [ "vps6" ];
          publicKey = "lNTwQqaR0w/loeG3Fh5qzQevuAVXhKXgiPt6fZoBGFE=";
          wireguardIp = "192.168.83.7";
        };
        slurm =
        {
          enable = false;
          cpu = { cores = 16; threads = 2; };
          memoryMB = 94208;
          gpus = { "3090" = 1; "4090" = 1; };
        };
        xrdp = { enable = false; hostname = [ "xmupc2.chn.moe" ]; };
        samba =
        {
          enable = true;
          hostsAllowed = "192.168. 127.";
          shares = { home.path = "/home"; root.path = "/"; };
        };
      };
      bugs = [ "xmunet" ];
      users.users = [ "chn" "xll" "zem" "yjq" "gb" ];
    };
  };
}
