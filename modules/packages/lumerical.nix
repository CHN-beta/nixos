inputs:
{
  options.nixos.packages.lumerical = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.packages) lumerical; in inputs.lib.mkIf (lumerical != null)
  {
    nixos =
    {
      packages.packages._packages = [ inputs.pkgs.localPackages.lumerical.lumerical.cmd ];
      services.lumericalLicenseManager = {};
    };
  };
}
