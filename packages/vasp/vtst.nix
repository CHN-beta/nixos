{ fetchzip, lib }:
let
  src = fetchzip
  {
    url = "http://theory.cm.utexas.edu/code/vtstcode-199.tgz";
    sha256 = "06c9f14a90ka3p396q6spr25xwkih4n01nm1qjj9fnvqzxlp9k9y";
  };
in "${src}/vtstcode6.4"
