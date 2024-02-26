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
            vfat."/dev/disk/by-uuid/467C-02E3" = "/boot/efi";
            btrfs =
            {
              "/dev/disk/by-uuid/2f9060bc-09b5-4348-ad0f-3a43a91d158b" = { "/nix" = "/nix"; "/nix/boot" = "/boot"; };
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
          rollingRootfs = { device = "/dev/disk/by-uuid/a04a1fb0-e4ed-4c91-9846-2f9e716f6e12"; path = "/nix/rootfs"; };
        };
        grub.installDevice = "efi";
        nixpkgs =
        {
          march = "znver3";
          cuda =
          {
            enable = true;
            capabilities =
            [
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
        gui.preferred = false;
        kernel.patches = [ "cjktty" "lantian" ];
        networking.hostname = "xmupc1";
      };
      hardware =
      {
        cpus = [ "amd" ];
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
          instances =
          {
            root = { device = "/"; hashTableSizeMB = 16384; threads = 4; };
            nix = { device = "/nix"; hashTableSizeMB = 512; };
          };
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
          cpu = { cores = 16; threads = 2; };
          memoryMB = 94208;
          gpus = { "3090" = 1; "4090" = 1; };
        };
      };
      bugs = [ "xmunet" "amdpstate" ];
      users.users = [ "chn" "xll" "zem" "yjq" "gb" ];
    };
  };
}
