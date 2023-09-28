{ lib, stdenv, fetchFromGitHub }: stdenv.mkDerivation rec
{
  pname = "nameof";
  version = "0.10.3";
  src = fetchFromGitHub
  {
    owner = "Neargye";
    repo = pname;
    rev = "v${version}";
    sha256 = "eHG0Y/BQGbwTrBHjq9SeSiIXaVqWp7PxIq7vCIECYPk=";
  };
  phases = [ "installPhase" ];
  installPhase =
  ''
    runHook preInstall
    mkdir -p $out
    cp -r $src/include $out
    runHook postInstall
  '';
}
