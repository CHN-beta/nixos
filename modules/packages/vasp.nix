inputs:
{
  options.nixos.packages.vasp = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    # default = if builtins.elem inputs.config.nixos.model.type [ "desktop" "server" ] then {} else null;
    # TODO: fix vasp
    default = null;
  };
  # TODO: add more options to correctly configure VASP
  config = let inherit (inputs.config.nixos.packages) vasp; in inputs.lib.mkIf (vasp != null)
  {
    nixos.packages.packages = with inputs.pkgs;
    {
      _packages =
      (
        [ localPackages.vasp.intel localPackages.vasp.vtst localPackages.vaspkit wannier90 ]
          ++ (inputs.lib.optional
            (let inherit (inputs.config.nixos.system.nixpkgs) cuda; in cuda.capabilities or null != null)
            localPackages.vasp.nvidia)
      );
      _pythonPackages = [(_: [ localPackages.py4vasp ])];
    };
  };
}
