inputs:
{
  config = inputs.lib.mkIf (builtins.elem "workstation" inputs.config.nixos.packages._packageSets)
  {
    nixos.packages._packages = with inputs.pkgs.localPackages.vasp; [ intel nvidia gnu vtstscripts ];
  };
}
