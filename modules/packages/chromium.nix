inputs:
{
  options.nixos.packages.chromium = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = if inputs.config.nixos.model.type == "desktop" then {} else null;
  };
  config = let inherit (inputs.config.nixos.packages) chromium; in inputs.lib.mkIf (chromium != null)
  {
    programs.chromium = { enable = true; extraOpts.PasswordManagerEnabled = false; };
  };
}
