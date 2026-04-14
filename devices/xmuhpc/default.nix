{ inputs, localLib }: rec
{
  pkgs = import inputs.nixpkgs (localLib.buildNixpkgsConfig
  {
    inputs = { inherit (inputs.nixpkgs) lib; flakeInputs = inputs; };
    nixpkgs = { march = "haswell"; nixos = false; isKernel310 = true; };
  });
  python = pkgs.python312.withPackages (ps: with ps; [ phonopy sumo ]);
  chn-bsub = pkgs.localPkgs.chn-bsub.override
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
    let python = pkgs.pkgs-2411.python310.withPackages (_: [ pkgs.localPkgs.pybinding ]);
    in pkgs.runCommand "python-lyj" { }
    ''
      mkdir -p $out/bin
      ln -s ${python}/bin/python3 $out/bin/python-lyj
    '';
  vasp = pkgs.symlinkJoin
  {
    name = "vasp";
    paths =
      let buildVaspFor = march: pkgs.localPkgs.vasp.intel.override (prev: { suffix = march; oneapiArch = march; });
      in builtins.map buildVaspFor ([ "core-avx2" "core-avx-i" ] ++ (pkgs.lib.unique (builtins.map (v: v.march)
        (builtins.attrValues (import ./bsub.nix)))));
  };
  banner = pkgs.runCommand "banner" {}
  ''
    mkdir -p $out/etc
    cp ${inputs.self}/modules/services/sshd/banner.txt $out/etc/banner
  '';
  potcar = pkgs.runCommand "potcar" {}
  ''
    mkdir -p $out/share
    ln -s ${inputs.self.src.vaspkit.potcar} $out/share/potcar
  '';
  hpcstat =
    let openssh = (pkgs.openssh.override { withLdns = false; etcDir = null; }).overrideAttrs
      (prev: { doCheck = false; patches = prev.patches ++ [ ./openssh.patch ];});
    in pkgs.localPkgs.hpcstat.override
      { inherit openssh; dataDir = "/data/gpfs01/jykang/linwei/chn/software/hpcstat/var/lib/hpcstat"; };

  wlin = mkEnv (with pkgs;
  [
    pv vasp chn-bsub zstd dotacat banner glibc.bin
  ]);
  jykang = mkEnv (with pkgs;
  [
    gnuplot localPkgs.vaspkit pv python-lyj sqlite zstd vasp chn-bsub potcar
    localPkgs.vasp.vtst wannier90 python
  ]);
  hwang = mkEnv (with pkgs;
  [
    pv vasp chn-bsub zstd
  ]);
}
# sudo nix build --store 'local?store=/data/gpfs01/wlin/.nix/store&state=/data/gpfs01/wlin/.nix/state&log=/data/gpfs01/wlin/.nix/log' .#wlin
# sudo nix-store --store 'local?store=/data/gpfs01/wlin/.nix/store&state=/data/gpfs01/wlin/.nix/state&log=/data/gpfs01/wlin/.nix/log' -qR ./result | grep -Fxv -f <(ssh wlin find .nix/store -maxdepth 1 -exec realpath '{}' '\;') | sudo xargs nix-store --store 'local?store=/data/gpfs01/wlin/.nix/store&state=/data/gpfs01/wlin/.nix/state&log=/data/gpfs01/wlin/.nix/log' --export | zstd | pv > wlin.nar.zstd
# pv wlin.nar.zstd | zstd -d | nix-store --import
