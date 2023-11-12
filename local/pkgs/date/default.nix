{ stdenv, fetchFromGitHub }: stdenv.mkDerivation
{
  name = "date";
  src = fetchFromGitHub
  {
    owner = "HowardHinnant";
    repo = "date";
    rev = "cc4685a21e4a4fdae707ad1233c61bbaff241f93";
    sha256 = "KilhBEeLMvHtS76Gu0UhzE8lhS1+sCwQ1UL4pswKXTs=";
  };
  phases = [ "installPhase" ];
  installPhase =
  ''
    runHook preInstall
    mkdir -p $out
    cp -r $src/{include,src} $out
  '';
}
