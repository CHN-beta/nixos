{ lib, config, ... }:
{
  config = lib.mkIf ((config.nixos.model.type == "desktop") && (config.nixos.model.arch == "x86_64"))
  {
    programs.direnv = { enable = true; nix-direnv.enable = true; };
    nixos.user.sharedModules = [{ config.programs.direnv.enable = true; }];
  };
}
