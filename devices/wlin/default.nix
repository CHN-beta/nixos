# sudo nix build --store 'local?store=/data/gpfs01/wlin/.nix/store&state=/data/gpfs01/wlin/.nix/state&log=/data/gpfs01/wlin/.nix/log' .#wlin
# sudo nix-store --store 'local?store=/data/gpfs01/wlin/.nix/store&state=/data/gpfs01/wlin/.nix/state&log=/data/gpfs01/wlin/.nix/log' -qR ./result | grep -Fxv -f <(ssh wlin find .nix/store -maxdepth 1 -exec realpath '{}' '\;') | sudo xargs nix-store --store 'local?store=/data/gpfs01/wlin/.nix/store&state=/data/gpfs01/wlin/.nix/state&log=/data/gpfs01/wlin/.nix/log' --export | pv > wlin.nar
# cat wlin.nar | nix-store --import
{ inputs, localLib }:
let
  pkgs = import inputs.nixpkgs (localLib.buildNixpkgsConfig
  {
    inputs = { inherit (inputs.nixpkgs) lib; topInputs = inputs; };
    nixpkgs = { march = "haswell"; nixRoot = "/data/gpfs01/wlin/.nix"; nixos = false; };
  });
  python = pkgs.python3.withPackages (ps: with ps; [ phonopy ]);
  chn-bsub = pkgs.localPackages.chn-bsub.override
    (prev: { bsubConfig = builtins.toFile "bsub.yaml" (builtins.toJSON (import ./bsub.nix)); });
  wlin = pkgs.symlinkJoin
  {
    name = "wlin";
    paths = with pkgs;
    [
      gnuplot localPackages.vaspkit pv python localPackages.vasp.intel chn-bsub hwloc
      lsd glibc glibc.bin
    ];
    postBuild = "echo ${inputs.self.rev or "dirty"} > $out/.version";
    passthru = { inherit pkgs chn-bsub; archive = pkgs.closureInfo { rootPaths = [ wlin.drvPath ]; }; };
  };
in wlin
