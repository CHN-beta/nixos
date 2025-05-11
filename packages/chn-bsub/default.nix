{ stdenv, lib, sbatchConfig ? null, runCommand, cmake, pkg-config, ftxui, biu }: stdenv.mkDerivation
{
  name = "chn-bsub";
  src = ./.;
  buildInputs = [ ftxui biu ];
  nativeBuildInputs = [ cmake pkg-config ];
  postInstall = "ln -s chn-bsub $out/bin/chn_bsub";
}
