{ inputs, localLib }:
let
  pkgs = import inputs.nixpkgs (localLib.buildNixpkgsConfig
  {
    inputs = { inherit (inputs.nixpkgs) lib; topInputs = inputs; };
    nixpkgs = { march = null; cuda = null; nixRoot = null; };
  });
in pkgs.symlinkJoin
{
  name = "xmuhk";
  paths = with pkgs; [ hello ];
  postBuild = "echo ${inputs.self.rev or "dirty"} > $out/.version";
}
