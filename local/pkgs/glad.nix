{ lib, stdenv, fetchFromGitHub, cmake, python3 }: stdenv.mkDerivation rec
{
  pname = "glad";
  version = "0.1.36";
  src = fetchFromGitHub
  {
    owner = "Dav1dde";
    repo = "glad";
    rev = "v${version}";
    sha256 = "FtkPz0xchwmqE+QgS+nSJVYaAfJSTUmZsObV/IPypVQ=";
  };
  cmakeFlags = [ "-DGLAD_REPRODUCIBLE=ON" "-DGLAD_INSTALL=ON" ];
  nativeBuildInputs = [ cmake python3 ];
}
