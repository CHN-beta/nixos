{ inputs, localLib }:
let
  pkgs = import inputs.nixpkgs (localLib.buildNixpkgsConfig
  {
    inputs = { inherit (inputs.nixpkgs) lib; topInputs = inputs; };
    nixpkgs = { march = "haswell"; nixRoot = "/data/gpfs01/wlin/.nix"; nixos = false; };
  });
in pkgs.symlinkJoin
{
  name = "wlin";
  paths = with pkgs; [ gnuplot localPackages.vaspkit pv ];
  postBuild = "echo ${inputs.self.rev or "dirty"} > $out/.version";
  passthru = { inherit pkgs; };
}
