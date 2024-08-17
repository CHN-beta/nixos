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
            vfat."/dev/disk/by-uuid/AE90-1DD1" = "/boot";
            btrfs."/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
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
      services.sshd = {};
    };
  };
}
