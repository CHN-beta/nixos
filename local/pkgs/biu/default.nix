{
  stdenv, fetchFromGitHub, cmake, pkg-config, ninja,
  fmt, boost, magic-enum, libbacktrace, concurrencpp, tgbot-cpp, nameof, eigen, range-v3
}: stdenv.mkDerivation rec
{
  name = "libbiu";
  src = fetchFromGitHub
  {
    owner = "CHN-beta";
    repo = "biu";
    rev = "8ed2e52968f98d3a6ddbd01e86e57604ba3a7f54";
    sha256 = "OqQ+QkjjIbpve/xn/DJA7ONw/bBg5zGNr+VJjc3o+K8=";
  };
  nativeBuildInputs = [ cmake pkg-config ninja ];
  buildInputs = [ fmt boost magic-enum libbacktrace concurrencpp tgbot-cpp nameof eigen range-v3 ];
  propagatedBuildInputs = buildInputs;
}
