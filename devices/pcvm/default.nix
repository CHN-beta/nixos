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
          swap = [ "/dev/mapper/swap" ];
          rollingRootfs = {};
        };
        grub.installDevice = "efi";
        networking.hostname = "pcvm";
        gui.enable = true;
        sops.enable = false;
      };
      hardware.cpus = [ "amd" ];
      packages.packageSet = "desktop-extra";
      services = { fontconfig.enable = true; sshd = {}; };
    };
    specialisation.xanmod.configuration =
    {
      nixos.system.kernel.variant = "xanmod-latest";
      system.nixos.tags = [ "xanmod" ];
    };
  };
}
