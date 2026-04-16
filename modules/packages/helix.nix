{ lib, config, pkgs, ... }:
{
  options.nixos.packages.helix = lib.mkOption
    { type = lib.types.nullOr (lib.types.submodule {}); default = {}; };
  config = let inherit (config.nixos.packages) helix; in lib.mkIf (helix != null)
  {
    nixos.user.sharedModules =
      [{ config.programs.helix = { enable = true; defaultEditor = true; settings.theme = "catppuccin_latte"; }; }];
    environment.systemPackages = [ pkgs.helix ];
  };
}
