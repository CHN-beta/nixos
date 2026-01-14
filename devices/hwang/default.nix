# sudo nix build --store 'local?store=/data/gpfs01/hwang/.nix/store&state=/data/gpfs01/hwang/.nix/state&log=/data/gpfs01/hwang/.nix/log' .#hwang
# sudo nix-store --store 'local?store=/data/gpfs01/hwang/.nix/store&state=/data/gpfs01/hwang/.nix/state&log=/data/gpfs01/hwang/.nix/log' -qR ./result | grep -Fxv -f <(ssh hwang find .nix/store -maxdepth 1 -exec realpath '{}' '\;') | sudo xargs nix-store --store 'local?store=/data/gpfs01/hwang/.nix/store&state=/data/gpfs01/hwang/.nix/state&log=/data/gpfs01/hwang/.nix/log' --export | pv > hwang.nar
# cat hwang.nar | nix-store --import
{ inputs, localLib }:
let
  pkgs = import inputs.nixpkgs (localLib.buildNixpkgsConfig
  {
    inputs = { inherit (inputs.nixpkgs) lib; topInputs = inputs; };
    nixpkgs = { march = "haswell"; nixos = false; };
  });
  hwang = pkgs.symlinkJoin
  {
    name = "hwang";
    paths = with pkgs; [ pv localPackages.vasp.intel glibc localPackages.vaspkit ];
    postBuild = "echo ${inputs.self.rev or "dirty"} > $out/.version";
    passthru = { inherit pkgs; archive = pkgs.closureInfo { rootPaths = [ hwang.drvPath ]; }; };
  };
in hwang
