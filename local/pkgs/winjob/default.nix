{
  stdenv, cmake, pkg-config, version ? null, lib,
  nlohmann_json, range-v3, sqlite-orm, boost
}: stdenv.mkDerivation
{
  name = "winjob";
  src = ./.;
  buildInputs = [ nlohmann_json range-v3 sqlite-orm boost ];
  nativeBuildInputs = [ cmake pkg-config ];
  cmakeFlags = lib.optionals (version != null) [ "-DWINJOB_VERSION=${version}" ];
}
