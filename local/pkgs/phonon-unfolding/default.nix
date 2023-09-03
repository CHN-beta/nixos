{
  stdenv, fetchFromGitHub, gfortran, blas
}:
stdenv.mkDerivation
{
  pname = "phonon-unfolding";
  version = "0";
  src = fetchFromGitHub
  {
    owner = "CHN-beta";
    repo = "phonon_unfolding";
    rev = "ec363ef2bad0ee18a0839a1681ea9915c0b72e1d";
    hash = "sha256-zDTbtYk5OXf//6eS4gEF7IvrpWcRAz18ue48IDZnfSk=";
  };
  buildInputs = [ blas ];
  nativeBuildInputs = [ gfortran ];
  buildPhase =
  ''
    gfortran PhononUnfoldingModule.f90 -o PhononUnfoldingModule.mod -c
    gfortran PhononUnfolding.f90 -c -o PhononUnfolding.mod
    gfortran PhononUnfolding.mod PhononUnfoldingModule.mod -o PhononUnfolding -lblas
  '';
  installPhase =
  ''
    mkdir -p $out/bin
    cp PhononUnfolding $out/bin
  '';
}
