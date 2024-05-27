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
            vfat."/dev/disk/by-uuid/ABD2-C06A" = "/boot/efi";
            btrfs =
            {
              "/dev/disk/by-uuid/e80edd17-f127-4820-8951-222d22d0301a" =
              {
                "/nix" = "/nix";
                "/nix/rootfs/current" = "/";
                "/nix/boot" = "/boot";
              };
            };
          };
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
