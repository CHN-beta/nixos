{
  stdenv, fetchFromGitHub, cmake, pkg-config, ninja,
  fmt, boost, magic-enum, libbacktrace, concurrencpp, tgbot-cpp, nameof, eigen, range-v3
}: stdenv.mkDerivation rec
{
  name = "libbiu";
  src = fetchFromGitHub
  {
    owner = "CHN-beta";
    repo = "libbiu";
    rev = "b048dd269e44a62c5220742ce697664088348e51";
    sha256 = "SxxLGj1Kqj4oUvWQvkpNAA6YnWt4sF5Gzclox9wl0uU=";
  };
  nativeBuildInputs = [ cmake pkg-config ninja ];
  buildInputs = [ fmt boost magic-enum libbacktrace concurrencpp tgbot-cpp nameof eigen range-v3 ];
  propagatedBuildInputs = buildInputs;
}
