{ stdenv, fetchFromGitHub, cmake, pkg-config, boost, openssl, zlib, curl }: stdenv.mkDerivation rec
{
  pname = "tgbot-cpp";
  version = "1.7.2";
  src = fetchFromGitHub
  {
    owner = "reo7sp";
    repo = "tgbot-cpp";
    rev = "v${version}";
    sha256 = "TKirSxEUqFB1WtzNEfU4EJK3p7V5xcFIvA2+QVX7TlA=";
  };
  nativeBuildInputs = [ cmake pkg-config ];
  buildInputs = [ boost openssl zlib curl.dev ];
  propagatedBuildInputs = buildInputs;
}
