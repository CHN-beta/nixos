{
  stdenv, cmake, pkg-config, version ? null, lib,
  boost, grpc
}: stdenv.mkDerivation
{
  name = "winjob";
  src = ./.;
  buildInputs = [ boost grpc ];
  nativeBuildInputs = [ cmake pkg-config ];
  cmakeFlags = lib.optionals (version != null) [ "-DWINJOB_VERSION=${version}" ];
}
