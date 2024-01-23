{ stdenv, src, cmake, pkg-config, boost, openssl, zlib, curl }: stdenv.mkDerivation rec
{
  name = "tgbot-cpp";
  inherit src;
  nativeBuildInputs = [ cmake pkg-config ];
  buildInputs = [ boost openssl zlib curl.dev ];
  propagatedBuildInputs = buildInputs;
}
