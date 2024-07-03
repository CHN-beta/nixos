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
            vfat."/dev/disk/by-uuid/AE90-1DD1" = "/boot/efi";
            btrfs =
            {
              "/dev/disk/by-uuid/5a043ec5-7b47-4b0d-ad89-8c3ce5650fcd"."/" = "/boot";
              "/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
            };
          };
          decrypt.auto."/dev/disk/by-uuid/a9e4a508-3f0b-492e-b932-e2019be28615" = { mapper = "root"; ssd = true; };
          rollingRootfs = {};
        };
        grub.installDevice = "efi";
        kernel.variant = "xanmod-latest";
        networking.hostname = "pcvm";
        initrd.sshd.enable = true;
      };
      hardware.cpus = [ "amd" ];
      packages.packageSet = "server";
      services.sshd = {};
    };
  };
}
