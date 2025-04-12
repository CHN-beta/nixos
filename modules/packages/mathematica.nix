inputs:
{
  options.nixos.packages.mathematica = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = null;
  };
  config = let inherit (inputs.config.nixos.packages) mathematica; in inputs.lib.mkIf (mathematica != null)
    { nixos.packages.packages._packages = [ inputs.pkgs.mathematica ]; };
}
