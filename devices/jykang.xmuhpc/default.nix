{ inputs, localLib }:
let pkgs = import inputs.nixpkgs (localLib.buildNixpkgsConfig
{
  inputs = { inherit (inputs.nixpkgs) lib; topInputs = inputs; };
  nixpkgs = { march = null; cuda = null; nixRoot = null; };
});
in (pkgs.symlinkJoin
{
  name = "jykang";
  paths = with pkgs; [ hello iotop gnuplot localPackages.vaspkit ];
  postBuild = "echo ${inputs.self.rev or "dirty"} > $out/.version";
}) // { inherit pkgs; }
