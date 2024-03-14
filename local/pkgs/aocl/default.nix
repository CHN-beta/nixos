{ stdenv, fetchurl }:

stdenv.mkDerivation rec
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
    installDir=$(mktemp -d)
    bash ./install.sh -t $installDir
    mkdir -p $out
    cp -r $installDir/${version}/aocc/lib_LP64 $out/lib
  '';
  dontFixup = true;
}
