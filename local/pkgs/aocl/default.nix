{ stdenv, fetchurl }:

stdenv.mkDerivation
{
  pname = "aocl";
  version = "4.2.0";
  src = fetchurl
  {
    url = "https://download.amd.com/developer/eula/aocl/aocl-4-2/aocl-linux-aocc-4.2.0.tar.gz";
    sha256 = "0p4x0zza6y18hjjs1971gyc5kjd2f8nzzynp2jabhl2vxiys2nnj";
  };
  dontBuild = true;
  installPhase =
  ''
    bash ./install.sh -t $out/share
  '';
  dontFixup = true;
}
