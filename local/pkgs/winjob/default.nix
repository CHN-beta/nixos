{
  stdenv, cmake, pkg-config, version ? null, lib,
  boost, nlohmann_json
}: stdenv.mkDerivation
{
  name = "winjob";
  src = ./.;
  buildInputs = [ boost nlohmann_json ];
  nativeBuildInputs = [ cmake pkg-config ];
  cmakeFlags = lib.optionals (version != null) [ "-DWINJOB_VERSION=${version}" ];
}
