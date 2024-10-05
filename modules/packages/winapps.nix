inputs:
{
  options.nixos.packages.winapps = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = if inputs.config.nixos.system.gui.enable then {} else null;
  };
  config = let inherit (inputs.config.nixos.packages) winapps; in inputs.lib.mkIf (winapps != null)
  {
    nixos.packages.packages._packages = [(inputs.pkgs.callPackage "${inputs.topInputs.winapps}/packages/winapps" {})];
  };
}
