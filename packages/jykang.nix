{ symlinkJoin, version, hello, nix }: symlinkJoin
{
  name = "jykang";
  paths = [ hello nix ];
  postBuild = "echo ${version} > $out/.version";
}
# sudo nix build --store 'local?store=/data/gpfs01/jykang/.nix/store&state=/data/gpfs01/jykang/.nix/state&log=/data/gpfs01/jykang/.nix/log' .#jykang
# sudo nix-store --store 'local?store=/data/gpfs01/jykang/.nix/store&state=/data/gpfs01/jykang/.nix/state&log=/data/gpfs01/jykang/.nix/log' -qR ./result | sudo xargs nix-store --store 'local?store=/data/gpfs01/jykang/.nix/store&state=/data/gpfs01/jykang/.nix/state&log=/data/gpfs01/jykang/.nix/log' --export > data.nar
# cat data.nar  | nix-store --import
