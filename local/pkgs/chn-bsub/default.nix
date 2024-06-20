{
  stdenv, lib, sbatchConfig ? null, substituteAll, runCommand,
  cmake, pkg-config, ftxui, biu, nlohmann_json
}:
stdenv.mkDerivation
{
  name = "chn-bsub";
  src = ./.;
  buildInputs = [ ftxui biu nlohmann_json ];
  nativeBuildInputs = [ cmake pkg-config ];
  postInstall = "ln -s chn-bsub $out/bin/chn_bsub";
}
