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
            vfat."/dev/disk/by-uuid/86B8-CF80" = "/boot/efi";
            btrfs =
            {
              "/dev/disk/by-uuid/e252f81d-b4b3-479f-8664-380a9b73cf83"."/boot" = "/boot";
              "/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
            };
          };
          decrypt.auto."/dev/disk/by-uuid/8186d34e-005c-4461-94c7-1003a5bd86c0" =
            { mapper = "root"; ssd = true; };
          swap = [ "/nix/swap/swap" ];
          rollingRootfs = { device = "/dev/mapper/root"; path = "/nix/rootfs"; };
        };
        nixpkgs.march = "skylake";
        grub.installDevice = "efi";
        nix.substituters = [ "https://cache.nixos.org/" "https://nix-store.chn.moe" ];
        kernel.patches = [ "cjktty" ];
        impermanence.enable = true;
        networking.hostname = "surface";
      };
      hardware =
      {
        cpus = [ "intel" ];
        gpus = [ "intel" ];
        bluetooth.enable = true;
        joystick.enable = true;
        printer.enable = true;
        sound.enable = true;
      };
      packages.packageSet = "desktop-fat";
      virtualization.docker.enable = true;
      services =
      {
        snapper.enable = true;
        fontconfig.enable = true;
        sshd.enable = true;
        xrayClient =
        {
          enable = true;
          serverAddress = "74.211.99.69";
          serverName = "vps6.xserver.chn.moe";
          dns.extraInterfaces = [ "docker0" ];
        };
        firewall.trustedInterfaces = [ "virbr0" ];
      };
      bugs = [ "xmunet" ];
    };
  };
}
