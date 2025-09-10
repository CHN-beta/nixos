# sudo nix build --store 'local?store=/data/gpfs01/jykang/.nix/store&state=/data/gpfs01/jykang/.nix/state&log=/data/gpfs01/jykang/.nix/log' .#jykang
# sudo nix-store --store 'local?store=/data/gpfs01/jykang/.nix/store&state=/data/gpfs01/jykang/.nix/state&log=/data/gpfs01/jykang/.nix/log' -qR ./result | grep -Fxv -f <(ssh jykang find .nix/store -maxdepth 1 -exec realpath '{}' '\;') | sudo xargs nix-store --store 'local?store=/data/gpfs01/jykang/.nix/store&state=/data/gpfs01/jykang/.nix/state&log=/data/gpfs01/jykang/.nix/log' --export | xz -T0 | pv > jykang.nar.xz
# cat data.nar | nix-store --import
{ inputs, localLib }:
let
  pkgs = import inputs.nixpkgs (localLib.buildNixpkgsConfig
  {
    inputs = { inherit (inputs.nixpkgs) lib; topInputs = inputs; };
    nixpkgs = { march = "haswell"; cuda = null; nixRoot = "/data/gpfs01/jykang/.nix"; nixos = false; };
  });
  python-cai =
    let py = pkgs.python3.withPackages (ps: with ps; [ pytorch ]);
    in pkgs.runCommand "python-cai" { }
    ''
      mkdir -p $out/bin
      ln -s ${py}/bin/python3 $out/bin/python-cai
    '';
in pkgs.symlinkJoin
{
  name = "jykang";
  paths = with pkgs; [ hello iotop gnuplot localPackages.vaspkit pv btop python-cai ];
  postBuild = "echo ${inputs.self.rev or "dirty"} > $out/.version";
  passthru = { inherit pkgs; };
}
