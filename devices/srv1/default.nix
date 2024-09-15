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
          mount = let inherit (inputs.config.nixos.system.cluster) clusterName nodeName; in
          {
            vfat."/dev/disk/by-partlabel/${clusterName}-${nodeName}-boot" = "/boot";
            btrfs."/dev/disk/by-partlabel/${clusterName}-${nodeName}-root" =
              { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
          };
          swap = [ "/nix/swap/swap" ];
          rollingRootfs = {};
        };
        kernel.variant = "xanmod-lts";
        gui.enable = true;
      };
      hardware.cpus = [ "intel" ];
      services =
      {
        snapper.enable = true;
        sshd = {};
        smartd.enable = true;
      };
      user.users = [ "chn" ];
    };
  };
}
