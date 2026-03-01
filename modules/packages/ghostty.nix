inputs:
{
  options.nixos.packages.ghostty = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = {}; };
  config = let inherit (inputs.config.nixos.packages) ghostty; in inputs.lib.mkIf (ghostty != null)
  {
    nixos =
    {
      user.sharedModules =
      [{
        config.programs.ghostty =
        {
          enable = true;
          settings = { scrollback-limit = 100000000; keybind = "ctrl+shift+r=reset"; linux-cgroup = "always"; };
        };
      }];
      packages.packages._packages = [ inputs.pkgs.ghostty ];
    };
  };
}
