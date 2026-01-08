{ lib, stdenv, cmake, pkg-config, biu, configFile ? null, httplib, sqlgen, nlohmann_json }: stdenv.mkDerivation
{
  name = "missgram";
  src = ./.;
  buildInputs = [ biu httplib sqlgen nlohmann_json ];
  nativeBuildInputs = [ cmake pkg-config ];
  cmakeFlags = lib.optional (configFile != null) [ "-DMISSGRAM_CONFIG_FILE=${configFile}" ];
}
