{ stdenv, cmake, pkg-config, slurm, biu }: stdenv.mkDerivation
{
  name = "info";
  src = ./.;
  buildInputs = [ slurm biu ];
  nativeBuildInputs = [ cmake pkg-config ];
}
