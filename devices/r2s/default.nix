inputs:
{
  config =
  {
    nixos =
    {
      model.arch = "aarch64";
      system =
      {
        fileSystems =
        {
          mount.btrfs."/dev/disk/by-partlabel/r2s-root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
          swap = [ "/nix/swap/swap" ];
        };
        network = {};
      };
      services =
      {
        sshd = {};
      };
    };
  };
}
