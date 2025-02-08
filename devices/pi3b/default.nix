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
            vfat."/dev/disk/by-uuid/ABC6-6B3E" = "/boot";
            btrfs."/dev/disk/by-uuid/c459c6c0-23a6-4ef2-945a-0bfafa9a45b6" =
              { "/nix/rootfs/current" = "/"; "/nix" = "/nix"; };
          };
          swap = [ "/nix/swap/swap" ];
          rollingRootfs = {};
        };
        networking = {};
        nixpkgs.arch = "aarch64";
        kernel.variant = "nixos";
      };
      services =
      {
        snapper = null;
        sshd = {};
        xray.client.enable = true;
        fail2ban = {};
        beesd.instances.root = { device = "/"; hashTableSizeMB = 32; };
      };
    };
  };
}
