{
  lib,
  stdenv,
  cmake,
  pkg-config,
  sbatchConfig ? null,
  ftxui,
  biu,
}:
stdenv.mkDerivation {
  name = "sbatch-tui";
  src = ./.;
  buildInputs = [
    ftxui
    biu
  ];
  nativeBuildInputs = [
    cmake
    pkg-config
  ];
  cmakeFlags = lib.optional (sbatchConfig != null) [ "-DSBATCH_CONFIG=${sbatchConfig}" ];
}
