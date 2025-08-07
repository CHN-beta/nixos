inputs:
{
  config =
  {
    nixos =
    {
      model.type = "desktop";
      system =
      {
        fileSystems =
        {
          mount =
          {
            vfat."/dev/disk/by-partlabel/steamdeck-boot" = "/boot";
            btrfs."/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
          };
          luks.auto."/dev/disk/by-partlabel/steamdeck-root" = { mapper = "root"; ssd = true; };
          swap = [ "/nix/swap/swap" ];
          resume = { device = "/dev/mapper/root"; offset = 4728064; };
        };
        nixpkgs.march = "znver2";
        kernel.variant = "steamos";
      };
      hardware = { gpu.type = "amd"; steamdeck = {}; };
      services =
      {
        xray.client = {};
        beesd."/".hashTableSizeMB = 64;
        sshd = {};
      };
      bugs = [ "xmunet" ];
    };
  };
}
