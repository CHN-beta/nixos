inputs:
{
  options.nixos.packages.android-studio = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = null;
  };
  config = let inherit (inputs.config.nixos.packages) android-studio; in inputs.lib.mkIf (android-studio != null)
  {
    nixos.packages.packages._packages = with inputs.pkgs; [ androidStudioPackages.stable.full ];
  };
}
