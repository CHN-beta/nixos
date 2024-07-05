inputs:
{
  config = inputs.lib.mkIf (builtins.elem "workstation" inputs.config.nixos.packages._packageSets)
  {
    nixos.packages._packages = inputs.lib.optionals (inputs.config.nixos.system.nixpkgs.march != null)
      (with inputs.pkgs.localPackages.vasp; [ intel nvidia vtstscripts ]);
  };
}
