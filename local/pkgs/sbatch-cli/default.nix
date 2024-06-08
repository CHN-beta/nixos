{ stdenv, cmake, pkg-config }: stdenv.mkDerivation
{
  name = "sbatch-cli";
  src = ./.;
  buildInputs = [];
  nativeBuildInputs = [ cmake pkg-config ];
}
