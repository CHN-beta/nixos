{ inputs, localLib }:
let
  pkgs = import inputs.nixpkgs (localLib.buildNixpkgsConfig
  {
    inputs = { inherit (inputs.nixpkgs) lib; topInputs = inputs; };
    nixpkgs = { march = "haswell"; nixRoot = "/data/gpfs01/wlin/.nix"; nixos = false; };
  });
  python = pkgs.python3.withPackages (ps: with ps; [ phonopy ]);
  wlin = pkgs.symlinkJoin
  {
    name = "wlin";
    paths = with pkgs; [ gnuplot localPackages.vaspkit pv python localPackages.vasp.intel ];
    postBuild = "echo ${inputs.self.rev or "dirty"} > $out/.version";
    passthru = { inherit pkgs; archive = pkgs.closureInfo { rootPaths = [ wlin.drvPath ]; }; };
  };
in wlin
