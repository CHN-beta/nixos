{ requireFile }:
let
  hashes =
  {
    # nix-store --query --hash $(nix store add-path ./vasp-6.4.0)
    "6.3.1" = "1xdr5kjxz6v2li73cbx1ls5b1lnm6z16jaa4fpln7d3arnnr1mgx";
    "6.4.0" = "189i1l5q33ynmps93p2mwqf5fx7p4l50sls1krqlv8ls14s3m71f";
  };
  sources = version: sha256: requireFile
  {
    name = "vasp-${version}";
    inherit sha256;
    hashMode = "recursive";
    message = "Source file not found.";
  };
in builtins.mapAttrs sources hashes
