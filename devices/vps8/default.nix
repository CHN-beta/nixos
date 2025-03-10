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
            btrfs =
            {
              "/dev/disk/by-uuid/0067ef91-06f7-416e-88cb-4880ce04afa4"."/boot" = "/boot";
              "/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
            };
          };
          swap = [ "/nix/swap/swap" ];
          rollingRootfs = {};
        };
        grub.installDevice = "/dev/disk/by-path/pci-0000:00:05.0-scsi-0:0:0:0";
        nixpkgs.march = "znver2";
        nix.substituters = [ "https://nix-store.chn.moe?priority=100" ];
        initrd.sshd = {};
        networking = {};
      };
      services =
      {
        sshd = {};
        beesd.instances.root = "/";
      };
    };
  };
}
