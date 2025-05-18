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
        networking = {};
      };
      hardware.cpus = [ "amd" ];
      services =
      {
        sshd = {};
        nixvirt =
        {
          subnet = 123;
          instance =
          {
            chn =
            {
              hardware = { memoryMB = 2048; cpus = 4; };
              network =
              {
                address = 2;
                portForward = { tcp = [{ host = 5693; guest = 22; }]; web = [ "example.chn.moe" ]; };
              };
            };
          };
        };
      };
    };
  };
}
