{
  lib, fetchFromGitHub, buildPythonPackage,
  tqdm, requests, torch, numpy, torchdata, cmake
}: buildPythonPackage rec
{
  pname = "torchtext";
  version = "0.16.1";
  src = fetchFromGitHub
  {
    owner = "pytorch";
    repo = "text";
    rev = "v${version}";
    hash = "sha256-4a33AWdd1VZwRL5vTawo0yplpw+qcNMetbfE1h1kafE=";
    fetchSubmodules = true;
  };
  dontUseCmakeConfigure = true;
  pyproject = true;
  propagatedBuildInputs = [ tqdm requests torch numpy torchdata ];
  nativeBuildInputs = [ cmake ];
}
