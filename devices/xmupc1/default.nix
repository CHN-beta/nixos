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
            vfat."/dev/disk/by-uuid/3F57-0EBE" = "/boot/efi";
            btrfs =
            {
              "/dev/disk/by-uuid/02e426ec-cfa2-4a18-b3a5-57ef04d66614"."/" = "/boot";
              "/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
            };
          };
          swap = [ "/dev/mapper/swap" ];
          resume = "/dev/mapper/swap";
          rollingRootfs = { device = "/dev/mapper/root"; path = "/nix/rootfs"; };
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
        kernel.patches = [ "cjktty" ];
        impermanence.enable = true;
        networking.hostname = "xmupc1";
      };
      hardware =
      {
        cpus = [ "amd" ];
        gpus = [ "nvidia" ];
        bluetooth.enable = true;
        joystick.enable = true;
        printer.enable = true;
        sound.enable = true;
        gamemode.drmDevice = 1;
      };
      packages.packageSet = "workstation";
      virtualization = { docker.enable = true; kvmHost = { enable = true; gui = true; }; };
      services =
      {
        snapper.enable = true;
        fontconfig.enable = true;
        samba =
        {
          enable = true;
          private = true;
          hostsAllowed = "192.168. 127.";
          shares =
          {
            media.path = "/run/media/chn";
            home.path = "/home/chn";
            mnt.path = "/mnt";
            share.path = "/home/chn/share";
          };
        };
        sshd.enable = true;
        xray.client =
        {
          enable = true;
          serverAddress = "74.211.99.69";
          serverName = "vps6.xserver.chn.moe";
          dns.extraInterfaces = [ "docker0" ];
        };
        firewall.trustedInterfaces = [ "virbr0" "waydroid0" ];
        acme = { enable = true; cert."debug.mirism.one" = {}; };
        smartd.enable = true;
        beesd = { enable = true; instances.root = { device = "/nix/persistent"; hashTableSizeMB = 2048; }; };
        wireguard =
        {
          enable = true;
          peers = [ "vps6" ];
          publicKey = "JEY7D4ANfTpevjXNvGDYO6aGwtBGRXsf/iwNwjwDRQk=";
          wireguardIp = "192.168.83.5";
        };
      };
      bugs = [ "xmunet" "firefox" ];
    };
  };
}
