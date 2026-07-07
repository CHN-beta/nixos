{
  config = {
    nixos = {
      system = {
        fileSystems = {
          mount = {
            vfat."/dev/disk/by-uuid/FBA6-4867" = "/boot";
            btrfs."/dev/disk/by-uuid/2d1d0b3f-9297-45b2-aede-ed6b258c81e0" = {
              "/nix/rootfs/current" = "/";
              "/nix" = "/nix";
            };
          };
          swap = [ "/nix/swap/swap" ];
        };
        grub.installDevice = "efiRemovable";
        kernel.patches = [ "btrfs" ];
      };
      services = {
        sshd = { };
      };
    };
  };
}
