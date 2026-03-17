{ lib, pkgs, config, ... }:
{
  options.nixos.packages.ghostty = lib.mkOption { type = lib.types.nullOr (lib.types.submodule {}); default = {}; };
  config = let inherit (config.nixos.packages) ghostty; in lib.mkIf (ghostty != null)
  {
    nixos =
    {
      user.sharedModules =
      [{
        config.programs.ghostty =
        {
          enable = true;
          package = pkgs.pkgs-unstable.ghostty;
          settings = { scrollback-limit = 100000000; keybind = "ctrl+shift+r=reset"; linux-cgroup = "always"; };
        };
      }];
      packages.packages._packages = [ pkgs.pkgs-unstable.ghostty ];
    };
  };
}
