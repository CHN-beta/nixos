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
            # TODO: reparition
            vfat."/dev/disk/by-uuid/CE84-E0D8" = "/boot";
            btrfs."/dev/disk/by-uuid/61f51d93-d3e5-4028-a903-332fafbfd365" =
              { "/nix/rootfs/current" = "/"; "/nix" = "/nix"; };
          };
          rollingRootfs = {};
        };
        grub.installDevice = "efi";
        networking = { hostname = "pcarm"; networkd = {}; };
        nixpkgs.arch = "aarch64";
        kernel.variant = "nixos";
        sops.enable = false;
      };
      services.sshd = {};
    };
  };
}
