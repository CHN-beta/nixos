{ lib, stdenv, cmake, pkg-config, biu, httplib, nlohmann_json }: stdenv.mkDerivation
{
  name = "xinli";
  src = ./.;
  buildInputs = [ biu httplib nlohmann_json ];
  nativeBuildInputs = [ cmake pkg-config ];
}
