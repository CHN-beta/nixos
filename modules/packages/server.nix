inputs:
{
  options.nixos.packages.server = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = if builtins.elem inputs.config.nixos.model.type [ "server" "desktop" ] then {} else null;
  };
  config = let inherit (inputs.config.nixos.packages) server; in inputs.lib.mkIf (server != null)
  {
    nixos.packages.packages =
    {
      _packages = with inputs.pkgs;
      [
        # office
        pdfgrep ffmpeg-full hdf5 immich-cli
        # scientific computing
        (if inputs.config.nixos.system.nixpkgs.cuda != null then localPackages.mumax else emptyDirectory)
        (if inputs.config.nixos.system.nixpkgs.cuda != null
          then (lammps.override { stdenv = cudaPackages.backendStdenv; }).overrideAttrs (prev:
          {
            cmakeFlags = prev.cmakeFlags ++
              [ "-DPKG_GPU=on" "-DGPU_API=cuda" "-DCMAKE_POLICY_DEFAULT_CMP0146=OLD" ];
            nativeBuildInputs = prev.nativeBuildInputs ++ [ cudaPackages.cudatoolkit ];
            buildInputs = prev.buildInputs ++ [ mpi ];
          })
          else lammps-mpi)
        # calculator
        numbat
        # development
        gcc go rustc nodejs
        # media
        localPackages.asmroner
      ];
      _pythonPackages = [(pythonPackages: with pythonPackages;
      [
        phonopy ruamel-yaml
        # for vasp plot-workfunc.py
        ase
      ])];
    };
  };
}
