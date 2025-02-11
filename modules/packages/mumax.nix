inputs:
{
  options.nixos.packages.mumax = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default =
      if (builtins.elem inputs.config.nixos.model.type [ "desktop" "server" ])
        && (let inherit (inputs.config.nixos.system.nixpkgs) cuda; in cuda.capabilities or null != null)
      then {}
      else null;
  };
  config = let inherit (inputs.config.nixos.packages) mumax; in inputs.lib.mkIf (mumax != null)
  {
    nixos.packages.packages._packages = [ inputs.pkgs.localPackages.mumax ];
  };
}
