{
  lib,
  stdenv,
  cmake,
  pkg-config,
  configFile ? null,
  slurm,
  biu,
}:
stdenv.mkDerivation {
  name = "info";
  src = ./.;
  buildInputs = [
    slurm
    biu
  ];
  nativeBuildInputs = [
    cmake
    pkg-config
  ];
  cmakeFlags = (lib.optionals (configFile != null) [ "-DINFO_CONFIG_FILE=${configFile}" ]);
}
