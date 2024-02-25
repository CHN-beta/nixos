{
  buildFHSEnv, writeScript, stdenvNoCC, requireFile, substituteAll,
  config, cudaCapabilities ? config.cudaCapabilities, nvhpcArch ? config.nvhpcArch or "px",
  nvhpc, lmod, mkl, gfortran, rsync, which, hdf5, wannier90
}:
let
  versions = import ../source.nix;
  buildEnv = buildFHSEnv
  {
    name = "buildEnv";
    targetPkgs = pkgs: with pkgs; [ zlib ];
  };
  buildScript = writeScript "build"
  ''
    . ${lmod}/share/lmod/lmod/init/bash
    module use ${nvhpc}/share/nvhpc/modulefiles
    module load nvhpc
    mkdir -p bin
    make DEPS=1 -j$NIX_BUILD_CORES
  '';
  include = version: substituteAll
  {
    src = ./makefile.include-${version};
    cudaCapabilities = builtins.concatStringsSep "," (builtins.map
      (cap: "cc${builtins.replaceStrings ["."] [""] cap}")
      cudaCapabilities);
    inherit nvhpcArch;
  };
  vasp = version: stdenvNoCC.mkDerivation rec
  {
    pname = "vasp";
    inherit version;
    src = requireFile
    {
      name = "${pname}-${version}";
      sha256 = versions.${version};
      hashMode = "recursive";
      message = "Source file not found.";
    };
    configurePhase =
    ''
      cp ${include version} makefile.include
      cp ${../constr_cell_relax.F} src/constr_cell_relax.F
    '';
    enableParallelBuilding = true;
    buildInputs = [ mkl hdf5 wannier90 ];
    nativeBuildInputs = [ gfortran rsync which ];
    MKLROOT = "${mkl}";
    HDF5_ROOT = "${hdf5}";
    WANNIER90_ROOT = "${wannier90}";
    buildPhase = "${buildEnv}/bin/buildEnv ${buildScript}";
    installPhase =
    ''
      mkdir -p $out/bin
      for i in std gam ncl; do cp bin/vasp_$i $out/bin/vasp-$i; done
    '';
  };
  startScript = version: writeScript "vasp-nvidia-${version}"
  ''
    . ${lmod}/share/lmod/lmod/init/bash
    module use ${nvhpc}/share/nvhpc/modulefiles
    module load nvhpc
    exec $@
  '';
  runEnv = version: buildFHSEnv
  {
    name = "vasp-nvidia-${version}";
    targetPkgs = pkgs: with pkgs; [ zlib (vasp version) ];
    runScript = startScript version;
  };
in builtins.mapAttrs (version: _: runEnv version) versions
