{ stdenv, fetchFromGitHub, cmake }: stdenv.mkDerivation
{
  name = "cppcoro";
  src = fetchFromGitHub
  {
    owner = "Garcia6l20";
    repo = "cppcoro";
    rev = "e1d53e620b0eee828915ada179cd7ca8e66ca855";
    sha256 = "luBkf1x5kqXaVbQM01yWRmA5QvrQNZkFVCjRctJdnXc=";
  };
  nativeBuildInputs = [ cmake ];
  patches = [ ./cppcoro-include-utility.patch ];
}
