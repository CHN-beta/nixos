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
            vfat."/dev/disk/by-partlabel/test-boot" = "/boot";
            btrfs."/dev/disk/by-partlabel/test-root1" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
          };
          rollingRootfs = {};
        };
        nixpkgs.march = "znver4";
        network = {};
      };
      hardware.cpus = [ "amd" ];
      services.sshd = {};
    };
  };
}
