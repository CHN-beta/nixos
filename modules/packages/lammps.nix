inputs:
{
  options.nixos.packages.lammps = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = if inputs.config.nixos.system.gui.enable then {} else null;
  };
  config = let inherit (inputs.config.nixos.packages) lammps; in inputs.lib.mkIf (lammps != null)
  {
    nixos.packages._packages =
      let cuda = let inherit (inputs.config.nixos.system.nixpkgs) cuda; in cuda.enable && cuda.capabilities != null;
      in
        if cuda then [((inputs.pkgs.lammps-mpi.override { stdenv = inputs.pkgs.cudaPackages.backendStdenv; })
          .overrideAttrs (prev:
          {
            cmakeFlags = prev.cmakeFlags ++ inputs.lib.optionals cuda
            [
              "-DPKG_GPU=on" "-DGPU_API=cuda" "-DCMAKE_POLICY_DEFAULT_CMP0146=OLD"
            ];
            nativeBuildInputs = prev.nativeBuildInputs ++ inputs.lib.optionals cuda
              [ inputs.pkgs.cudaPackages.cudatoolkit ];
          }))]
        else [ inputs.pkgs.lammps-mpi ];
  };
}
