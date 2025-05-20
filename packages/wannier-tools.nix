{ stdenv, src, gfortran, lapack }: stdenv.mkDerivation
{
  name = "wannier-tools";
  inherit src;
  nativeBuildInputs = [ gfortran ];
  buildInputs = [ lapack ];
  buildPhase = "cd src; cp Makefile.gfortran Makefile; make";
  installPhase = "mkdir -p $out/bin && cp wt.x $out/bin";
}
