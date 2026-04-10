{ lib, config, ... }:
{
  options.nixos.packages.direnv = lib.mkOption
  {
    type = lib.types.nullOr (lib.types.submodule {});
    default =
      if (config.nixos.model.type == "desktop") && (config.nixos.model.arch == "x86_64") then {}
      else null;
  };
  config = let inherit (config.nixos.packages) direnv; in lib.mkIf (direnv != null)
  {
    programs.direnv = { enable = true; nix-direnv.enable = true; };
    nixos.user.sharedModules = [{ config.programs.direnv.enable = true; }];
  };
}
