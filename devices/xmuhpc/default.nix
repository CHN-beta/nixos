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
  vasp = pkgs.symlinkJoin
  {
    name = "vasp";
    paths =
      let buildVaspFor = march: pkgs.localPackages.vasp.intel.override (prev: { suffix = march; oneapiArch = march; });
      in builtins.map buildVaspFor (pkgs.lib.unique (builtins.map (v: v.march)
        (builtins.attrValues (import ./bsub.nix))));
  };
  banner = pkgs.runCommand "banner" {}
  ''
    mkdir -p $out/etc
    cp ${inputs.self}/modules/services/sshd/banner.txt $out/etc/banner
  '';

  wlin = mkEnv (with pkgs;
  [
    pv vasp chn-bsub zstd lolcat banner
  ]);
  jykang = mkEnv (with pkgs;
  [
    gnuplot localPackages.vaspkit pv python-lyj sqlite zstd vasp chn-bsub banner
  ]);
  hwang = mkEnv (with pkgs;
  [
    pv vasp chn-bsub zstd
  ]);
}
# sudo nix build --store 'local?store=/data/gpfs01/wlin/.nix/store&state=/data/gpfs01/wlin/.nix/state&log=/data/gpfs01/wlin/.nix/log' .#wlin
# sudo nix-store --store 'local?store=/data/gpfs01/wlin/.nix/store&state=/data/gpfs01/wlin/.nix/state&log=/data/gpfs01/wlin/.nix/log' -qR ./result | grep -Fxv -f <(ssh wlin find .nix/store -maxdepth 1 -exec realpath '{}' '\;') | sudo xargs nix-store --store 'local?store=/data/gpfs01/wlin/.nix/store&state=/data/gpfs01/wlin/.nix/state&log=/data/gpfs01/wlin/.nix/log' --export | zstd | pv > wlin.nar.zstd
# pv wlin.nar.zstd | zstd -d | nix-store --import
