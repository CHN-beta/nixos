{ lib, stdenv, cmake, pkg-config, biu, httplib, nlohmann_json, openssl }: stdenv.mkDerivation
{
  name = "xinli";
  src = ./.;
  buildInputs = [ biu httplib nlohmann_json openssl ];
  nativeBuildInputs = [ cmake pkg-config ];
}
