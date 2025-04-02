# sudo nix build --store 'local?store=/data/gpfs01/jykang/.nix/store&real=/nix/store' .#jykang
# sudo nix-store --store 'local?store=/data/gpfs01/jykang/.nix/store&real=/nix/store' -qR ./result | sudo xargs nix-store --store 'local?store=/data/gpfs01/jykang/.nix/store&real=/nix/store' --export > data.nar
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
  paths = with pkgs; [ hello iotop ];
  postBuild = "echo ${inputs.self.rev or "dirty"} > $out/.version";
}
