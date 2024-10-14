inputs:
{
  options.nixos.packages.helix = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = {}; };
  config = let inherit (inputs.config.nixos.packages) helix; in inputs.lib.mkIf (helix != null)
  {
    nixos.user.sharedModules =
    [{
      config.programs.helix =
      {
        enable = true;
        defaultEditor = true;
        settings.theme = "catppuccin_latte";
      };
    }];
  };
}
