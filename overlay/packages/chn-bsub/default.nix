{
  stdenv,
  cmake,
  pkg-config,
  ftxui,
  biu,
  bsubConfig ? null,
  lib,
}:
stdenv.mkDerivation {
  name = "chn-bsub";
  src = ./.;
  buildInputs = [
    ftxui
    biu
  ];
  nativeBuildInputs = [
    cmake
    pkg-config
  ];
  postInstall = "ln -s chn-bsub $out/bin/chn_bsub";
  cmakeFlags = lib.optional (bsubConfig != null) [ "-DBSUB_CONFIG=${bsubConfig}" ];
  passthru = { inherit bsubConfig; };
}
