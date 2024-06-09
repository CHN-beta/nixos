{ stdenv, cmake, pkg-config, fmt, ftxui, boost, range-v3, sbatchConfig ? null, substituteAll, runCommand, lib }:
stdenv.mkDerivation
{
  name = "sbatch-tui";
  src = ./.;
  preConfigure = lib.optionalString (sbatchConfig != null)
    "cp ${substituteAll ({ src = ./src/device.cpp.template; } // sbatchConfig)} src/device.cpp";
  buildInputs = [ fmt ftxui boost range-v3 ];
  nativeBuildInputs = [ cmake pkg-config ];
}
