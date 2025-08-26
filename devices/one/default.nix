inputs:
{
  config =
  {
    nixos =
    {
      model = { type = "desktop"; private = true; };
      system =
      {
        fileSystems =
        {
          mount =
          {
            vfat."/dev/disk/by-partlabel/one-boot" = "/boot";
            btrfs."/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
          };
          luks.auto."/dev/disk/by-partlabel/one-root" = { mapper = "root"; ssd = true; };
          swap = [ "/nix/swap/swap" ];
          resume = { device = "/dev/mapper/root"; offset = 4728064; };
        };
        nixpkgs.march = "tigerlake";
      };
      hardware.gpu.type = "intel";
      services =
      {
        xray.client = {};
        beesd."/".hashTableSizeMB = 64;
        sshd = {};
        waydroid = {};
      };
      bugs = [ "xmunet" ];
    };
    specialisation.niri.configuration.nixos.system.gui.implementation = "niri";
    services.fprintd =
    {
      enable = true;
      package =
        let pkgs = inputs.pkgs.pkgs-2411;
        in pkgs.fprintd.override { libfprint = pkgs.libfprint-focaltech-2808-a658; };
    };
    boot.extraModulePackages =
      [(inputs.config.boot.kernelPackages.callPackage inputs.pkgs.localPackages.focal-spi {})];
  };
}
