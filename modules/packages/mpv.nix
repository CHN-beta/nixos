{ pkgs, lib, config, ... }:
{
  options.nixos.packages.mpv = lib.mkOption
  {
    type = lib.types.nullOr (lib.types.submodule {});
    default = if config.nixos.model.type == "desktop" then {} else null;
  };
  config = let inherit (config.nixos.packages) mpv; in lib.mkIf (mpv != null)
  {
    nixos.user.sharedModules = [{ config.programs.mpv = { enable = true; scripts = [ pkgs.mpvScripts.mpris ]; }; }];
    environment.systemPackages = [ pkgs.mpv ];
  };
}
