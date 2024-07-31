{
  stdenv, lib, sbatchConfig ? null, substituteAll, runCommand,
  cmake, pkg-config, ftxui, biu
}:
stdenv.mkDerivation
{
  name = "sbatch-tui";
  src = ./.;
  preConfigure = lib.optionalString (sbatchConfig != null)
    "cp ${substituteAll ({ src = ./src/device.cpp.template; } // sbatchConfig)} src/device.cpp";
  buildInputs = [ ftxui biu ];
  nativeBuildInputs = [ cmake pkg-config ];
}
