{ pkgs, ... }:
{
  config =
  {
    environment.systemPackages = [ pkgs.btop ];
    nixos.user.sharedModules = [{ config.programs.btop = { enable = true; settings.btrfs_group_subvolumes = true; }; }];
  };
}
