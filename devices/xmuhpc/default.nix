{ inputs, localLib }: rec
{
  pkgs = import inputs.nixpkgs (localLib.buildNixpkgsConfig
  {
    inputs = { inherit (inputs.nixpkgs) lib; topInputs = inputs; };
    nixpkgs = { march = "haswell"; nixos = false; isKernel310 = true; };
  });
  python = pkgs.python3.withPackages (ps: with ps; [ phonopy ]);
  chn-bsub = pkgs.localPackages.chn-bsub.override
    (prev: { bsubConfig = builtins.toFile "bsub.yaml" (builtins.toJSON (import ./bsub.nix)); });
  mkEnv = paths:
    let result = pkgs.symlinkJoin
    {
      name = "env";
      inherit paths;
      postBuild = "echo ${inputs.self.rev or "dirty"} > $out/.version";
      passthru.archive = pkgs.closureInfo { rootPaths = [ result.drvPath ]; };
    };
    in result;
  python-lyj =
    let python = pkgs.pkgs-2411.python310.withPackages (_: [ pkgs.localPackages.pybinding ]);
    in pkgs.runCommand "python-lyj" { }
    ''
      mkdir -p $out/bin
      ln -s ${python}/bin/python3 $out/bin/python-lyj
    '';

  wlin = mkEnv (with pkgs;
  [
    gnuplot localPackages.vaspkit pv python localPackages.vasp.intel chn-bsub hwloc
    lsd glibc glibc.bin
  ]);
  jykang = mkEnv (with pkgs;
  [
    gnuplot localPackages.vaspkit pv python-lyj sqlite
  ]);
  hwang = mkEnv (with pkgs;
  [
    pv localPackages.vasp.intel glibc localPackages.vaspkit chn-bsub
  ]);
}
# sudo nix build --store 'local?store=/data/gpfs01/wlin/.nix/store&state=/data/gpfs01/wlin/.nix/state&log=/data/gpfs01/wlin/.nix/log' .#wlin
# sudo nix-store --store 'local?store=/data/gpfs01/wlin/.nix/store&state=/data/gpfs01/wlin/.nix/state&log=/data/gpfs01/wlin/.nix/log' -qR ./result | grep -Fxv -f <(ssh wlin find .nix/store -maxdepth 1 -exec realpath '{}' '\;') | sudo xargs nix-store --store 'local?store=/data/gpfs01/wlin/.nix/store&state=/data/gpfs01/wlin/.nix/state&log=/data/gpfs01/wlin/.nix/log' --export | pv > wlin.nar
# cat wlin.nar | nix-store --import
