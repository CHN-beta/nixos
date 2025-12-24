inputs:
{
  options.nixos.packages.zellij = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = {}; };
  config = let inherit (inputs.config.nixos.packages) zellij; in inputs.lib.mkIf (zellij != null)
  {
    nixos =
    {
      packages.packages._packages = [ inputs.pkgs.zellij ];
      user.sharedModules =
      [{
        config.programs.zellij =
        {
          enable = true;
          settings = { scroll_buffer_size = 100000000; show_startup_tips = false; show_release_notes = false; };
        };
      }];
    };
  };
}
