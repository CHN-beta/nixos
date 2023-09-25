{ stdenv, fetchFromGitHub }: stdenv.mkDerivation rec
{
  pname = "zpp-bits";
  version = "4.4.19";
  src = fetchFromGitHub
  {
    owner = "eyalz800";
    repo = "zpp_bits";
    rev = "v${version}";
    sha256 = "ejIwrvCFALuBQbQhTfzjBb11oMR/akKnboB60GWbjlQ=";
  };
  phases = [ "installPhase" ];
  installPhase =
  ''
    mkdir -p $out/include
    cp $src/zpp_bits.h $out/include
  '';
}
