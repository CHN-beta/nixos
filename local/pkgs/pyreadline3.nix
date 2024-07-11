{
  lib, fetchFromGitHub, buildPythonPackage
}: buildPythonPackage rec
{
  pname = "pyreadline3";
  version = "3.4.1";
  src = fetchFromGitHub
  {
    owner = "pyreadline3";
    repo = "pyreadline3";
    rev = "v${version}";
    hash = "sha256-02/gkx955NupVKXSu/xBQQtY4SEP4zxbNQYg1oQ/nGY=";
  };
}
