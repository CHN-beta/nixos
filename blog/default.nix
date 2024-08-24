{ stdenv, hextra, hugo }: stdenv.mkDerivation
{
  name = "blog";
  src = ./.;
  nativeBuildInputs = [ hugo ];
  configurePhase =
  ''
    mkdir themes
    ln -s ${hextra} themes/hextra
  '';
  buildPhase = "hugo";
  installPhase = "cp -r public $out";
}
