{
  lib, fetchFromGitHub, buildPythonPackage,
  torch, urllib3, requests, cmake, pkg-config, ninja
}: buildPythonPackage rec
{
  pname = "torchdata";
  version = "0.7.1";
  src = fetchFromGitHub
  {
    owner = "pytorch";
    repo = "data";
    rev = "v${version}";
    hash = "sha256-SOeu+mI4p2tHX0YyctrDBcrz2/zYcwH9GGJ+6ytRmjQ=";
    fetchSubmodules = true;
  };
  dontUseCmakeConfigure = true;
  pyproject = true;
  propagatedBuildInputs = [ torch urllib3 requests ];
  nativeBuildInputs = [ cmake pkg-config ninja ];
}
