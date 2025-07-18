{ stdenv, src, autoPatchelfHook, xorg }: stdenv.mkDerivation
{
  name = "atomkit";
  inherit src;
  dontConfigure = true;
  dontBuild = true;
  buildInputs = [ stdenv.cc.cc xorg.libX11 ];
  nativeBuildInputs = [ autoPatchelfHook ];
  installPhase =
  ''
    runHook preInstall
    mkdir -p $out
    cp -r * $out
    runHook postInstall
  '';
}
