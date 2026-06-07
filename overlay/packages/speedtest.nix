{ stdenv, src }:
stdenv.mkDerivation {
  name = "speedtest";
  inherit src;
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    mkdir -p $out
    cp -r $src/{index.html,speedtest.js,speedtest_worker.js,favicon.ico,backend} $out
  '';
}
