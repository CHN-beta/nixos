inputs:
{
  options.nixos.packages.mumax = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.packages) mumax; in inputs.lib.mkIf (mumax != null)
  {
    nixos.packages.packages._packages = [ inputs.pkgs.localPackages.mumax ];
  };
}
