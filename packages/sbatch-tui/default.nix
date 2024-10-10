{ stdenv, cmake, pkg-config, ftxui, biu }: stdenv.mkDerivation
{
  name = "sbatch-tui";
  src = ./.;
  buildInputs = [ ftxui biu ];
  nativeBuildInputs = [ cmake pkg-config ];
}
