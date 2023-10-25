{ stdenvNoCC, texlive, fetchFromGitHub }: stdenvNoCC.mkDerivation (finalAttrs: rec
{
  pname = "latex-citation-style-language";
  version = "0.4.5";
  passthru = {
    pkgs = [ finalAttrs.finalPackage ];
    tlDeps = with texlive; [ latex ];
    tlType = "run";
  };

  src = fetchFromGitHub
  {
    owner = "zepinglee";
    repo = "citeproc-lua";
    rev = "v${version}";
    sha256 = "XH+GH+t/10hr4bfaod8F9JPxmBnAQlDmpSvQNDQsslM=";
    fetchSubmodules = true;
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
