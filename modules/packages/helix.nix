{ pkgs, ... }:
{
  config =
  {
    nixos.user.sharedModules =
      [{ config.programs.helix = { enable = true; defaultEditor = true; settings.theme = "catppuccin_latte"; }; }];
    environment.systemPackages = [ pkgs.helix ];
  };
}
