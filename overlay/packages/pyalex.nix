{
  fetchFromGitHub,
  buildPythonPackage,
  setuptools,
  setuptools-scm,
  requests,
  urllib3,
}:

buildPythonPackage rec {
  pname = "pyalex";
  version = "0.18";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "J535D165";
    repo = "pyalex";
    rev = "v${version}";
    sha256 = "084504hfzw2nc6isg3mh67j5n37kg6nli4fcm797cjpvrxyday0y";
  };

  build-system = [
    setuptools
    setuptools-scm
  ];

  dependencies = [
    requests
    urllib3
  ];

  doCheck = false;

  meta = {
    description = "Python interface to the OpenAlex database";
    homepage = "https://github.com/J535D165/pyalex";
  };
}
