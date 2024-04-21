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
            vfat."/dev/disk/by-uuid/CE84-E0D8" = "/boot/efi";
            btrfs."/dev/disk/by-uuid/61f51d93-d3e5-4028-a903-332fafbfd365" =
              { "/nix/rootfs/current" = "/"; "/nix" = "/nix"; "/nix/boot" = "/boot"; };
          };
          rollingRootfs = {};
        };
        grub.installDevice = "efi";
        networking = { hostname = "pcarm"; networkd = {}; };
        nixpkgs.arch = "aarch64";
        kernel.variant = "nixos";
      };
      packages.packageSet = "server";
      services.sshd = {};
    };
  };
}
