inputs:
{
  options.nixos.packages.vasp = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.packages) vasp; in inputs.lib.mkIf (vasp != null)
  {
    nixos.packages.packages = with inputs.pkgs;
    {
      _packages =
      [
        localPackages.vasp.intel localPackages.vasp.vtst localPackages.vaspkit wannier90
        (if inputs.config.nixos.system.nixpkgs.cuda != null then localPackages.vasp.nvidia else emptyDirectory)
        localPackages.atomkit (inputs.lib.mkAfter localPackages.atat)
      ];
      _pythonPackages = [(_: [ localPackages.py4vasp ])];
    };
  };
}
