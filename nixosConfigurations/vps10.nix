{
  config = {
    nixos = {
      system = {
        fileSystems = {
          mount = {
            vfat."/dev/disk/by-partlabel/vps10-boot" = "/boot";
            btrfs."/dev/mapper/root" = {
              "/nix" = "/nix";
              "/nix/rootfs/current" = "/";
            };
          };
          swap = [ "/nix/swap/swap" ];
          luks."/dev/disk/by-partlabel/vps10-root" = {
            mapper = "root";
            ssd = true;
          };
        };
        initrd.sshd = { };
        nixpkgs.march = "x86-64-v3";
        network.settings.dhcp = [ "ens18" ];
      };
      services = {
        sshd = { };
        fail2ban = { };
      };
    };
  };
}
