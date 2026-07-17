{
  lib,
  config,
  pkgs,
  self,
  ...
}:
{
  options.nixos.packages.server = lib.mkOption {
    type = lib.types.nullOr (lib.types.submodule { });
    default =
      if
        builtins.elem config.nixos.model.variant [
          "server"
          "desktop"
        ]
      then
        { }
      else
        null;
  };
  config = lib.mkIf (config.nixos.packages.server != null) (
    lib.mkMerge [
      {
        environment.systemPackages = with pkgs; [
          # office
          pdfgrep
          ffmpeg-full
          hdf5
          immich-cli
          # scientific computing
          (if config.nixos.system.nixpkgs.cuda != null then localPkgs.mumax else emptyDirectory)
          (
            if config.nixos.system.nixpkgs.cuda != null then
              (lammps.override { stdenv = cudaPackages.backendStdenv; }).overrideAttrs (prev: {
                cmakeFlags = prev.cmakeFlags ++ [
                  "-DPKG_GPU=on"
                  "-DGPU_API=cuda"
                  "-DCMAKE_POLICY_DEFAULT_CMP0146=OLD"
                ];
                nativeBuildInputs = prev.nativeBuildInputs ++ [ cudaPackages.cudatoolkit ];
                buildInputs = prev.buildInputs ++ [ mpi ];
              })
            else
              lammps-mpi
          )
          (
            let
              umpire = pkgs.umpire.override {
                cudaSupport = false;
                rocmSupport = false;
              };
              sirius = pkgs.sirius.override {
                gpuBackend = "none";
                inherit umpire;
              };
              cp2k = pkgs.cp2k.override {
                gpuBackend = "none";
                inherit sirius;
              };
            in
            pkgs.runCommand "cp2k-cpu" { } ''
              mkdir -p $out/bin
              ln -s ${cp2k}/bin/cp2k.psmp $out/bin/cp2k-cpu
            ''
          )
          (
            if pkgs.config.cudaSupport || pkgs.config.rocmSupport then
              pkgs.runCommand "cp2k-gpu" { } ''
                mkdir -p $out/bin
                ln -s ${pkgs.cp2k}/bin/cp2k.psmp $out/bin/cp2k-gpu
              ''
            else
              pkgs.emptyDirectory
          )
          # calculator
          numbat
          # development
          gcc
          go
          rustc
          cargo
          nodejs
          pnpm
          yarn
          tio
          uv
          nixfmt
          # media
          localPkgs.asmroner
        ];
        nixos.packages.pythonPackages = [
          (
            pythonPackages: with pythonPackages; [
              phonopy
              ruamel-yaml
              pymatgen
              pymatgen-analysis-defects
              doped
              # for vasp plot-workfunc.py
              ase
            ]
          )
        ];
      }
    ]
  );
}
