{
  lib,
  stdenv,
  cmake,
  pkg-config,
  vmConfig ? null,
  biu,
}:
stdenv.mkDerivation {
  name = "vm";
  src = ./.;
  buildInputs = [ biu ];
  nativeBuildInputs = [
    cmake
    pkg-config
  ];
  cmakeFlags = lib.optional (vmConfig != null) [ "-DVM_CONFIG=${vmConfig}" ];
}
