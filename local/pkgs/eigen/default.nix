{ lib, stdenv, fetchFromGitLab, cmake }: stdenv.mkDerivation rec
{
  name = "eigen";
  src = fetchFromGitLab
  {
    owner = "libeigen";
    repo = name;
    rev = "6d829e766ff1b1ab867d93631163cbc63ed5798f";
    sha256 = "BXUnizcRPrOyiPpoyYJ4VVOjlG49aj80mgzPKmEYPKU=";
  };
  nativeBuildInputs = [ cmake ];
}
