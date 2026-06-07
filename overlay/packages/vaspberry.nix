{
  stdenv,
  src,
  gfortran,
  lapack,
}:
stdenv.mkDerivation {
  name = "vaspberry";
  inherit src;
  nativeBuildInputs = [ gfortran ];
  buildInputs = [ lapack ];
  buildPhase = "gfortran vaspberry_gfortran_serial.f -std=legacy -llapack -o vaspberry";
  installPhase = "mkdir -p $out/bin && cp vaspberry $out/bin";
}
