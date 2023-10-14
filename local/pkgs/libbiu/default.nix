{
  stdenv, fetchFromGitHub, cmake, pkg-config, ninja,
  fmt, boost, magic-enum, libbacktrace, concurrencpp, tgbot-cpp, nameof
}: stdenv.mkDerivation rec
{
  name = "libbiu";
  src = fetchFromGitHub
  {
    owner = "CHN-beta";
    repo = "libbiu";
    rev = "46a23a7ee377f870a16b4591acf6d691a8e217cf";
    sha256 = "c9wRTzb9EVVOsRvrtm+zj17b5hmorVeJ9L+iBbPA+cw=";
  };
  nativeBuildInputs = [ cmake pkg-config ninja ];
  buildInputs = [ fmt boost magic-enum libbacktrace concurrencpp tgbot-cpp nameof ];
  propagatedBuildInputs = buildInputs;
}
