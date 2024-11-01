inputs:
{
  options.nixos.packages.vasp = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = if builtins.elem inputs.config.nixos.model.type [ "desktop" "server" ] then {} else null;
  };
  # TODO: add more options to correctly configure VASP
  config = let inherit (inputs.config.nixos.packages) vasp; in inputs.lib.mkIf (vasp != null)
  {
    nixos.packages.packages._packages = with inputs.pkgs;
    (
      [ localPackages.vasp.intel localPackages.vasp.vtstscripts localPackages.py4vasp localPackages.vaspkit wannier90 ]
        ++ (inputs.lib.optional
          (let inherit (inputs.config.nixos.system.nixpkgs) cuda; in cuda.enable && cuda.capabilities != null)
          localPackages.vasp.nvidia)
    );
  };
}
