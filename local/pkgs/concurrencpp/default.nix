{ stdenv, fetchFromGitHub, cmake }: stdenv.mkDerivation rec
{
  pname = "concurrencpp";
  version = "0.1.7";
  src = fetchFromGitHub
  {
    owner = "David-Haim";
    repo = "concurrencpp";
    rev = "v.${version}";
    sha256 = "4qT29YVjKEWcMrI5R5Ps8aD4grAAgz5VOxANjpp1oTo=";
  };
  nativeBuildInputs = [ cmake ];
  postInstall =
  ''
    mv $out/include/concurrencpp-${version}/concurrencpp $out/include
    rm -rf $out/include/concurrencpp-${version}
  '';
}
