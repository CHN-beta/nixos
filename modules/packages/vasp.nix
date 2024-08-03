inputs:
{
  options.nixos.packages.vasp = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = if inputs.config.nixos.system.gui.enable then {} else null;
  };
  # TODO: add more options to correctly configure VASP
  config = let inherit (inputs.config.nixos.packages) vasp; in inputs.lib.mkIf (vasp != null)
  {
    nixos.packages.packages._packages = inputs.lib.optionals (inputs.config.nixos.system.nixpkgs.march != null)
      (with inputs.pkgs.localPackages.vasp; [ intel nvidia vtstscripts ]);
  };
}
