{ lib, stdenv, bundlerEnv, fetchFromGitHub }:
let
  pname = "huginn";
  version = "20230723";
  src = fetchFromGitHub
  {
    owner = "CHN-beta";
    repo = "huginn";
    rev = "a02977ad420a01b6460634af19f714db4a8f8f36";
    hash = "sha256-Ty2EDCIjbvcf3PzPupcV4s7ZfAFTuYEjSfy0m+Yt3j4=";
  };
  gems = bundlerEnv
  {
    name = "${pname}-${version}-gems";
    gemdir  = "${src}";
    gemfile = "${src}/Gemfile";
    lockfile = "${src}/Gemfile.lock";
    gemset  = "${src}/gemset.nix";
    copyGemFiles = true;
  };
in stdenv.mkDerivation
{
  inherit pname version src;
  buildInputs = [ gems gems.wrappedRuby ];
  installPhase =
  ''
    false
  '';
}
