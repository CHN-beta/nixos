{ stdenv, src }: stdenv.mkDerivation
{
  inherit src;
  name = "zpp-bits";
  phases = [ "installPhase" ];
  installPhase =
  ''
    mkdir -p $out/include
    cp $src/zpp_bits.h $out/include
  '';
}
