# sudo nix build --store 'local?store=/data/gpfs01/jykang/.nix/store&state=/data/gpfs01/jykang/.nix/state&log=/data/gpfs01/jykang/.nix/log' .#jykang
# sudo nix-store --store 'local?store=/data/gpfs01/jykang/.nix/store&state=/data/gpfs01/jykang/.nix/state&log=/data/gpfs01/jykang/.nix/log' -qR ./result | sudo xargs nix-store --store 'local?store=/data/gpfs01/jykang/.nix/store&state=/data/gpfs01/jykang/.nix/state&log=/data/gpfs01/jykang/.nix/log' --export > data.nar
# cat data.nar  | nix-store --import
inputs:
let pkgs = import inputs.nixpkgs (import ../../modules/system/nixpkgs/buildNixpkgsConfig.nix
{
  inputs = { inherit (inputs.nixpkgs) lib; topInputs = inputs; };
  nixpkgs = { march = null; cuda = null; nixRoot = "/data/gpfs01/jykang/.nix"; };
});
in pkgs.symlinkJoin
{
  name = "jykang";
  paths = with pkgs; [ hello ];
  postBuild = "echo ${inputs.self.rev or "dirty"} > $out/.version";
}
