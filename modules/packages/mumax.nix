inputs:
{
  options.nixos.packages.mumax = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default =
      if inputs.config.nixos.system.gui.enable
        && (let inherit (inputs.config.nixos.system.nixpkgs) cuda; in cuda.enable && cuda.capabilities != null)
      then {}
      else null;
  };
  config = let inherit (inputs.config.nixos.packages) mumax; in inputs.lib.mkIf (mumax != null)
  {
    nixos.packages.packages._packages = [ inputs.pkgs.localPackages.mumax ];
  };
}
