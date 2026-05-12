{ lib, stdenv, cmake, pkg-config, biu, configFile ? null, httplib, sqlgen, nlohmann_json, libmaddy-markdown }:
stdenv.mkDerivation
{
  name = "missgram";
  src = ./.;
  buildInputs = [ biu httplib sqlgen nlohmann_json libmaddy-markdown ];
  nativeBuildInputs = [ cmake pkg-config ];
  cmakeFlags = lib.optional (configFile != null) [ "-DMISSGRAM_CONFIG_FILE=${configFile}" ];
}
