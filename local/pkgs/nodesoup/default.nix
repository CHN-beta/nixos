{ stdenv, src, cmake, pkg-config, cairo, pcre2, xorg }: stdenv.mkDerivation
{
  name = "nodesoup";
  inherit src;
  buildInputs = [ cairo pcre2.dev xorg.libXdmcp.dev ];
  nativeBuildInputs = [ cmake pkg-config ];
}
