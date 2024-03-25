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
            vfat."/dev/disk/by-uuid/ABC6-6B3E" = "/boot/efi";
            btrfs."/dev/disk/by-uuid/c459c6c0-23a6-4ef2-945a-0bfafa9a45b6" =
              { "/nix/rootfs/current" = "/"; "/nix" = "/nix"; "/nix/boot" = "/boot"; };
          };
          swap = [ "/nix/swap/swap" ];
          rollingRootfs = {};
        };
        grub.installDevice = "efi";
        networking = { hostname = "pi3b"; networkd = {}; };
        binfmt.enable = false;
        nixpkgs.arch = "aarch64";
        kernel.varient = "rpi3";
      };
      packages.packageSet = "server";
    };
  };
}
