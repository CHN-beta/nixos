{ pkgs, lib, config, ... }:
{
  config = lib.mkIf (config.nixos.model.type == "desktop")
  {
    nixos.user.sharedModules = [{ config.programs.mpv = { enable = true; scripts = [ pkgs.mpvScripts.mpris ]; }; }];
    environment.systemPackages = [ pkgs.mpv ];
  };
}
