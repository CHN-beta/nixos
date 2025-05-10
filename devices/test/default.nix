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
        nixpkgs.march = "haswell";
        networking = {};
      };
      hardware.cpus = [ "intel" ];
      services =
      {
        sshd = {};
        nginx = { enable = true; applications.example = {}; };
      };
    };
  };
}
