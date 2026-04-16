{ pkgs, ... }:
{
  config =
  {
    nixos.user.sharedModules =
    [{
      config.programs.ghostty =
      {
        enable = true;
        package = pkgs.pkgs-unstable.ghostty;
        settings = { scrollback-limit = 100000000; keybind = "ctrl+shift+r=reset"; linux-cgroup = "always"; };
      };
    }];
    environment.systemPackages = [ pkgs.pkgs-unstable.ghostty ];
  };
}
