{ lib, stdenv, cmake, pkg-config, biu, configFile ? null, httplib, sqlgen }: stdenv.mkDerivation
{
  name = "missgram";
  src = ./.;
  buildInputs = [ biu httplib sqlgen ];
  nativeBuildInputs = [ cmake pkg-config ];
  cmakeFlags = lib.optional (configFile != null) [ "-DMISSGRAM_CONFIG_FILE=${configFile}" ];
}
