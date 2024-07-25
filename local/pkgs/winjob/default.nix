{
  stdenv, cmake, pkg-config, version ? null, lib,
  boost
}: stdenv.mkDerivation
{
  name = "winjob";
  src = ./.;
  buildInputs = [ boost ];
  nativeBuildInputs = [ cmake pkg-config ];
  cmakeFlags = lib.optionals (version != null) [ "-DWINJOB_VERSION=${version}" ];
}
