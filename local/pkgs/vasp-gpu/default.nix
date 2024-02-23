{
  buildFHSEnv, writeScript, stdenvNoCC, requireFile, substituteAll,
  config, cudaCapabilities ? config.cudaCapabilities, nvhpcArch ? config.nvhpcArch or "px",
  nvhpc, lmod, mkl, gfortran, rsync, which
}:
let
  env = buildFHSEnv
  {
    name = "env";
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
  include = substituteAll
  {
    src = ./makefile.include;
    cudaCapabilities = builtins.concatStringsSep "," (builtins.map
      (cap: "cc${builtins.replaceStrings ["."] [""] cap}")
      cudaCapabilities);
    inherit nvhpcArch;
  };
  vasp = stdenvNoCC.mkDerivation rec
  {
    pname = "vasp";
    version = "6.4.0";
    # nix-store --query --hash $(nix store add-path ./vasp-6.4.0)
    src = requireFile
    {
      name = "${pname}-${version}";
      sha256 = "189i1l5q33ynmps93p2mwqf5fx7p4l50sls1krqlv8ls14s3m71f";
      hashMode = "recursive";
      message = "Source file not found.";
    };
    configurePhase = "cp ${include} makefile.include";
    enableParallelBuilding = true;
    buildInputs = [ gfortran mkl rsync which ];
    MKLROOT = "${mkl}";
    buildPhase = "${env}/bin/env ${buildScript}";
    installPhase =
    ''
      mkdir -p $out/bin
      for i in std gam ncl; do cp bin/vasp_$i $out/bin/vasp-$i; done
    '';
  };
  startScript = writeScript "start"
  ''
    . ${lmod}/share/lmod/lmod/init/bash
    module use ${nvhpc}/share/nvhpc/modulefiles
    module load nvhpc
    exec $@
  '';
in buildFHSEnv
{
  name = "vasp-gpu";
  targetPkgs = pkgs: with pkgs; [ zlib vasp ];
  runScript = startScript;
}
