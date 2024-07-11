{ lib, fetchFromGitHub, rustPlatform, pkg-config, openssl }:
rustPlatform.buildRustPackage rec
{
  pname = "mk-meili-mgn";
  version = "20230827";
  src = fetchFromGitHub
  {
    owner = "CHN-beta";
    repo = "mk-meili-mgn";
    rev = "53e282c992293ec735c9bc964f097b5bdbc3e48a";
    hash = "sha256-KBSoEGfWKDXZHSzSzak1v0nxtQQGI15DQTyNAPhsIB4=";
  };
  cargoHash = "sha256-wNdMPPl2H2iSrNYjoij0Qg/c2S5RjTHpOMV1RfHU27g=";
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ openssl ];
}
