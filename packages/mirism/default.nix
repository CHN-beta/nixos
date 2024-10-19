{ stdenv, cmake, pkg-config, biu, httplib }: stdenv.mkDerivation
{
  name = "mirism";
  src = ./.;
  buildInputs = [ biu httplib ];
  nativeBuildInputs = [ cmake pkg-config ];
}
