{ stdenv, src, autoPatchelfHook, libX11 }: stdenv.mkDerivation
{
  name = "atomkit";
  inherit src;
  dontConfigure = true;
  dontBuild = true;
  buildInputs = [ stdenv.cc.cc libX11 ];
  nativeBuildInputs = [ autoPatchelfHook ];
  installPhase =
  ''
    runHook preInstall
    mkdir -p $out
    cp -r * $out
    runHook postInstall
  '';
}
