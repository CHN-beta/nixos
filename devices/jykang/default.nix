# sudo nix build --store 'local?store=/data/gpfs01/jykang/.nix/store&state=/data/gpfs01/jykang/.nix/state&log=/data/gpfs01/jykang/.nix/log' .#jykang
# sudo nix-store --store 'local?store=/data/gpfs01/jykang/.nix/store&state=/data/gpfs01/jykang/.nix/state&log=/data/gpfs01/jykang/.nix/log' -qR ./result | grep -Fxv -f <(ssh jykang find .nix/store -maxdepth 1 -exec realpath '{}' '\;') | sudo xargs nix-store --store 'local?store=/data/gpfs01/jykang/.nix/store&state=/data/gpfs01/jykang/.nix/state&log=/data/gpfs01/jykang/.nix/log' --export | xz -T0 | pv > jykang.nar.xz
# cat data.nar | nix-store --import
{ inputs, localLib }:
let
  pkgs = import inputs.nixpkgs (localLib.buildNixpkgsConfig
  {
    inputs = { inherit (inputs.nixpkgs) lib; topInputs = inputs; };
    nixpkgs = { march = "haswell"; nixRoot = "/data/gpfs01/jykang/.nix"; nixos = false; };
  });
  python-lyj =
    let python = pkgs.pkgs-2411.python310.withPackages (_: [ pkgs.localPackages.pybinding ]);
    in pkgs.runCommand "python-lyj" { }
    ''
      mkdir -p $out/bin
      ln -s ${python}/bin/python3 $out/bin/python-lyj
    '';
  jykang = pkgs.symlinkJoin
  {
    name = "jykang";
    paths = with pkgs; [ gnuplot localPackages.vaspkit pv python-lyj sqlite ];
    postBuild = "echo ${inputs.self.rev or "dirty"} > $out/.version";
    passthru = { inherit pkgs; archive = pkgs.closureInfo { rootPaths = [ jykang.drvPath ]; }; };
  };
in jykang
