{ lib, config, pkgs, ... }:
{
  options.nixos.packages.server = lib.mkOption
  {
    type = lib.types.nullOr (lib.types.submodule {});
    default = if builtins.elem config.nixos.model.variant [ "server" "desktop" ] then {} else null;
  };
  config = lib.mkIf (config.nixos.packages.server != null)
  {
    environment.systemPackages = with pkgs;
    [
      # office
      pdfgrep ffmpeg-full hdf5 immich-cli
      # scientific computing
      (if config.nixos.system.nixpkgs.cuda != null then localPkgs.mumax else emptyDirectory)
      (if config.nixos.system.nixpkgs.cuda != null
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
      gcc go rustc nodejs pnpm yarn tio
      # media
      localPkgs.asmroner
    ];
    nixos.packages.pythonPackages = [(pythonPackages: with pythonPackages;
    [
      phonopy ruamel-yaml
      # for vasp plot-workfunc.py
      ase
    ])];
  };
}
