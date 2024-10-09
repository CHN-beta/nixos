{ src, python3, stdenv }: stdenv.mkDerivation
{
  name = "spectroscopy";
  phases = [ "installPhase" "fixupPhase" ];
  buildInputs = [ python3 ];
  installPhase =
  ''
    mkdir -p $out/${python3.sitePackages}
    cp -r ${src}/lib/spectroscopy $out/${python3.sitePackages}
    cp -r ${src}/scripts $out/bin
  '';
}
