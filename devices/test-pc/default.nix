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
        networking = { dhcp = [ "nixvirt" ]; bridge.nixvirt.devs = [ "enp1s0" ]; };
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
              memory.sizeMB = 2048;
              cpu.count = 4;
              network =
              {
                bridge = true;
                vnc.port = 15901;
              };
            };
            chn2 =
            {
              owner = "chn";
              memory.sizeMB = 2048;
              cpu.count = 4;
              network = { address = 3; portForward.tcp = [{ host = 5694; guest = 22; }]; };
            };
          };
        };
      };
    };
  };
}
