{ stdenv, src, writeShellScriptBin, rsync, which, wannier90, hdf5, mkl, mpi }:
let vasp = stdenv.mkDerivation
{
  name = "vasp-nvidia";
  src = src.vasp;
  patches = [ ../vtst.patch ];
  configurePhase =
  ''
    cp ${./makefile.include} makefile.include
    chmod +w makefile.include
    cp ${../constr_cell_relax.F} src/constr_cell_relax.F
    cp -r ${src.vtst.patch}/vtstcode6.4.3/* src
    chmod -R +w src
  '';
  buildInputs = [ hdf5 wannier90 mkl ];
  nativeBuildInputs = [ rsync which mpi ];
  installPhase =
  ''
    mkdir -p $out/bin
    for i in std gam ncl; do cp bin/vasp_$i $out/bin/vasp-$i; done
  '';

  enableParallelBuilding = true;
  env = { DEPS = "1"; MKLROOT = mkl; QD = "${stdenv.cc.cc}/Linux_x86_64/${stdenv.cc.cc.version}/compilers/extras/qd"; };
};
in writeShellScriptBin "vasp-nvidia"
''
  export PATH=${vasp}/bin:${mpi}/bin''${PATH:+:$PATH}

  ulimit -s unlimited

  # set OMP_NUM_THREADS if SLURM_CPUS_PER_TASK is set
  if [ -z "$OMP_NUM_THREADS" ] && [ -n "$SLURM_CPUS_PER_TASK" ]; then
    export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
  fi

  exec ${stdenv.cc.cc.runEnv} "$@"
''
