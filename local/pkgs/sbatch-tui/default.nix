{ stdenv, cmake, pkg-config, fmt, ftxui, boost, range-v3 }: stdenv.mkDerivation
{
  name = "sbatch-tui";
  src = ./.;
  buildInputs = [ fmt ftxui boost range-v3 ];
  nativeBuildInputs = [ cmake pkg-config ];
}
