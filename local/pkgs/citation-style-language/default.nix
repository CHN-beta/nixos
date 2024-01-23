{ stdenvNoCC, texlive, src }: stdenvNoCC.mkDerivation (finalAttrs:
{
  name = "citation-style-language";
  inherit src;
  passthru =
  {
    pkgs = [ finalAttrs.finalPackage ];
    tlDeps = with texlive; [ latex ];
    tlType = "run";
  };

  nativeBuildInputs = [ texlive.combined.scheme-full ];
  dontConfigure = true;
  dontBuild = true;
  installPhase =
  ''
    runHook preInstall
    export TEXMFHOME=$out
    l3build install
    runHook postInstall
  '';
})
