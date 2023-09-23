{ stdenv, fetchFromGitHub, cmake, pkg-config, cairo, pcre2, xorg }: stdenv.mkDerivation rec
{
  name = "nodesoup";
  src = fetchFromGitHub
  {
    owner = "olvb";
    repo = "nodesoup";
    rev = "3158ad082bb0cd1abee75418b12b35522dbca74f";
    sha256 = "tFLq6QC3U3uvcuWsdRy2wnwcmAfH2MkI2oMcAiUBHSo=";
  };
  buildInputs = [ cairo pcre2.dev xorg.libXdmcp.dev ];
  nativeBuildInputs = [ cmake pkg-config ];
}
