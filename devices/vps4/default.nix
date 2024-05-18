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
              "/dev/disk/by-uuid/24577c0e-d56b-45ba-8b36-95a848228600"."/boot" = "/boot";
              "/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
            };
          };
          swap = [ "/nix/swap/swap" ];
          rollingRootfs = {};
        };
        grub.installDevice = "/dev/disk/by-path/pci-0000:00:05.0-scsi-0:0:0:0";
        nixpkgs.march = "znver2";
        nix.substituters = [ "https://cache.nixos.org/" "https://nix-store.chn.moe" ];
        initrd.sshd.enable = true;
        networking = { hostname = "vps4"; networkd = {}; };
        kernel.variant = "cachyos-server";
      };
      services =
      {
        snapper.enable = true;
        sshd = {};
        fail2ban = {};
        beesd.instances.root = { device = "/"; hashTableSizeMB = 64; };
      };
    };
  };
}
