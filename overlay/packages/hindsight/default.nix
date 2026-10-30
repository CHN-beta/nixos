{
  pkgs,
  src,
  uv2nix,
  pyproject-nix,
  pyproject-build-systems,
}:
{
  api = pkgs.callPackage ./api.nix {
    inherit
      src
      uv2nix
      pyproject-nix
      pyproject-build-systems
      ;
    python = pkgs.python313;
  };
  control-plane = pkgs.callPackage ./control-plane.nix { };
}
