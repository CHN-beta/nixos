inputs:
{
  options.nixos.packages.molecule = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = if inputs.config.nixos.model.type == "desktop" then {} else null;
  };
  config = let inherit (inputs.config.nixos.packages) molecule; in inputs.lib.mkIf (molecule != null)
  {
    nixos.packages.packages._packages = with inputs.pkgs;
      [ ovito localPackages.vesta localPackages.v-sim localPackages.ufo inputs.pkgs.pkgs-2311.hdfview ];
  };
}
