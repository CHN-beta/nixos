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
            vfat."/dev/disk/by-uuid/E58F-416A" = "/boot/efi";
            btrfs =
            {
              "/dev/disk/by-uuid/066be4fd-8617-4fe1-9654-c133c2996d33"."/" = "/boot";
              "/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
            };
          };
          swap = [ "/nix/swap/swap" ];
          rollingRootfs = {};
        };
        grub.installDevice = "efi";
        networking = { hostname = "pi3b"; networkd = {}; };
        binfmt.enable = false;
      };
      packages.packageSet = "server";
    };
  };
}
