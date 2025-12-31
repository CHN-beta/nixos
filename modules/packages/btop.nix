{ lib, pkgs, config, ... }:
{
  options.nixos.packages.btop = lib.mkOption { type = lib.types.nullOr (lib.types.submodule {}); default = {}; };
  config = let inherit (config.nixos.packages) btop; in lib.mkIf (btop != null)
  {
    nixos =
    {
      packages.packages._packages = [ pkgs.btop ];
      user.sharedModules =
      [{
        config.programs.btop =
        {
          enable = true;
          settings.btrfs_group_subvolumes = true;
        };
      }];
    };
  };
}
