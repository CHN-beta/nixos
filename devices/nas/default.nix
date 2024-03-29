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
            vfat."/dev/disk/by-uuid/13BC-F0C9" = "/boot/efi";
            btrfs =
            {
              "/dev/disk/by-uuid/0e184f3b-af6c-4f5d-926a-2559f2dc3063"."/boot" = "/boot";
              "/dev/mapper/nix"."/nix" = "/nix";
              "/dev/mapper/root1" =
              {
                "/nix/rootfs" = "/nix/rootfs";
                "/nix/persistent" = "/nix/persistent";
                "/nix/nodatacow" = "/nix/nodatacow";
                "/nix/rootfs/current" = "/";
                "/nix/backup" = "/nix/backup";
              };
            };
          };
          decrypt.manual =
          {
            enable = true;
            devices =
            {
              "/dev/disk/by-uuid/5cf1d19d-b4a5-4e67-8e10-f63f0d5bb649".mapper = "root1";
              "/dev/disk/by-uuid/aa684baf-fd8a-459c-99ba-11eb7636cb0d".mapper = "root2";
              "/dev/disk/by-uuid/a779198f-cce9-4c3d-a64a-9ec45f6f5495" = { mapper = "nix"; ssd = true; };
            };
            delayedMount = [ "/" "/nix" ];
          };
          swap = [ "/nix/swap/swap" ];
          rollingRootfs.waitDevices = [ "/dev/mapper/root2" ];
        };
        initrd.sshd.enable = true;
        grub.installDevice = "efi";
        nixpkgs.march = "silvermont";
        nix.substituters = [ "https://cache.nixos.org/" "https://nix-store.chn.moe" ];
        kernel.patches = [ "cjktty" "lantian" ];
        networking = { hostname = "nas"; networkd = {}; };
        gui.preferred = false;
      };
      hardware = { cpus = [ "intel" ]; gpu.type = "intel"; };
      packages.packageSet = "desktop-fat";
      services =
      {
        snapper.enable = true;
        fontconfig.enable = true;
        samba =
        {
          enable = true;
          hostsAllowed = "192.168. 127.";
          shares = { home.path = "/home"; root.path = "/"; };
        };
        sshd.enable = true;
        xray.client.dae.wanInterface = [ "enp3s0" ];
        xrdp = { enable = true; hostname = [ "nas.chn.moe" "office.chn.moe" ]; };
        groupshare = {};
        smartd.enable = true;
        beesd.instances =
        {
          root = { device = "/"; hashTableSizeMB = 4096; threads = 4; };
          nix = { device = "/nix"; hashTableSizeMB = 128; };
        };
        frpClient =
        {
          enable = true;
          serverName = "frp.chn.moe";
          user = "nas";
          stcp.hpc = { localIp = "hpc.xmu.edu.cn"; localPort = 22; };
        };
        nginx = { enable = true; applications.webdav.instances."local.webdav.chn.moe" = {}; };
        wireguard =
        {
          enable = true;
          peers = [ "vps6" ];
          publicKey = "xCYRbZEaGloMk7Awr00UR3JcDJy4AzVp4QvGNoyEgFY=";
          wireguardIp = "192.168.83.4";
        };
      };
      user.users = [ "chn" "xll" "zem" "yjq" "gb" ];
    };
  };
}
