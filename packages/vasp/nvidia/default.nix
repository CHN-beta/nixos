{
  stdenv, src, writeShellScriptBin,
  rsync, which, wannier90, hdf5, vtst, mkl
}:
let vasp = stdenv.mkDerivation
{
  name = "vasp-nvidia";
  inherit src;
  patches = [ ../vtst.patch ];
  configurePhase =
  ''
    cp ${./makefile.include} makefile.include
    chmod +w makefile.include
    cp ${../constr_cell_relax.F} src/constr_cell_relax.F
    cp -r ${vtst}/vtstcode6.4.3/* src
    chmod -R +w src
  '';
  buildInputs = [ hdf5 wannier90 mkl ];
  nativeBuildInputs = [ rsync which ];
  installPhase =
  ''
    mkdir -p $out/bin
    for i in std gam ncl; do cp bin/vasp_$i $out/bin/vasp-$i; done
    mkdir $out/src
    ln -s ${src} $out/src/vasp
    ln -s ${vtst} $out/src/vtst
  '';

  # enable parallel build
  enableParallelBuilding = true;
  env =
  {
    DEPS = "1";
    # vasp directly include headers under ${mkl}/include/fftw
    MKLROOT = mkl;
    QD = "${stdenv.cc.cc}/Linux_x86_64/${stdenv.cc.cc.version}/compilers/extras/qd";
  };
};
in writeShellScriptBin "vasp-nvidia"
''
  export PATH=${vasp}/bin''${PATH:+:$PATH}
  exec ${stdenv.cc.cc.runEnv} "$@"
''
