{
  config = {
    nixos = {
      system = {
        fileSystems = {
          mount = {
            vfat."/dev/disk/by-partlabel/pe-boot" = "/boot";
            btrfs."/dev/disk/by-partlabel/pe-root" = {
              "/nix/rootfs/current" = "/";
              "/nix" = "/nix";
            };
          };
          swap = [ "/nix/swap/swap" ];
        };
        grub.installDevice = "hybrid:/dev/sda";
        kernel.patches = [ "btrfs" ];
      };
      services = {
        sshd = { };
      };
    };
  };
}
