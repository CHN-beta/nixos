{ fetchzip, lib }: version:
  let
    src = fetchzip
    {
      url = "http://theory.cm.utexas.edu/code/vtstcode-199.tgz";
      sha256 = "06c9f14a90ka3p396q6spr25xwkih4n01nm1qjj9fnvqzxlp9k9y";
    };
    shortVersion = builtins.concatStringsSep "." (lib.lists.take 2 (builtins.splitVersion version));
  in if version == null then src else "${src}/vtstcode${shortVersion}"
