{ stdenv, fetchurl }:

stdenv.mkDerivation
{
  pname = "aocc";
  version = "4.2.0";
  src = fetchurl
  {
    url = "https://download.amd.com/developer/eula/aocc/aocc-4-2/aocc-compiler-4.2.0.tar";
    sha256 = "1aycw6ygzr1db6xf3z7v5lpznhs8j7gcpkawd304vcj5qw75cnpd";
  };
  dontBuild = true;
  installPhase =
  ''
    mkdir -p $out
    cp -r bin include lib lib32 libexec share $out
  '';
  dontFixup = true;
}
