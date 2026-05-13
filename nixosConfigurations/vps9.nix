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
            btrfs =
            {
              "/dev/disk/by-partlabel/vps9-boot"."/boot" = "/boot";
              "/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
            };
          };
          swap = [ "/nix/swap/swap" ];
          luks."/dev/disk/by-partlabel/vps9-root" = { mapper = "root"; ssd = true; };
        };
        grub.installDevice = "/dev/disk/by-path/pci-0000:06:0a.0";
        nixpkgs.march = "znver3";
        initrd.sshd = {};
      };
      services =
      {
        sshd = {};
        fail2ban = {};
      };
    };
  };
}
