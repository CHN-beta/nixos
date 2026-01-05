{ inputs, localLib }: rec
{
  pkgs = import inputs.nixpkgs (localLib.buildNixpkgsConfig
  {
    inputs = { inherit (inputs.nixpkgs) lib; topInputs = inputs; };
    nixpkgs = { march = null; nixos = false; };
  });
  hpcstat =
    let
      openssh = (pkgs.pkgsStatic.openssh.override { withLdns = false; etcDir = null; }).overrideAttrs
        (prev: { doCheck = false; patches = prev.patches ++ [ ../packages/hpcstat/openssh.patch ];});
      duc = pkgs.pkgsStatic.duc.override { enableCairo = false; cairo = null; pango = null; };
      glaze = pkgs.pkgs-2411.pkgsStatic.glaze.overrideAttrs
        (prev: { cmakeFlags = prev.cmakeFlags ++ [ "-Dglaze_ENABLE_FUZZING=OFF" ]; });
      biu = pkgs.pkgsStatic.localPackages.biu.override { inherit glaze; };
    in pkgs.pkgsStatic.localPackages.hpcstat.override
    {
      inherit openssh duc biu;
      standalone = true;
      version = inputs.self.rev or "dirty";
      stdenv = pkgs.pkgsStatic.gcc14Stdenv;
    };
  inherit (pkgs.localPackages.pkgsStatic) chn-bsub;
  vaspberry = pkgs.pkgsStatic.localPackages.vaspberry.override
  {
    gfortran = pkgs.pkgsStatic.gfortran;
    lapack = pkgs.pkgsStatic.openblas;
  };
  jykang = import ../devices/jykang { inherit inputs localLib; };
  wlin = import ../devices/wlin { inherit inputs localLib; };
  xmuhk = import ../devices/xmuhk { inherit inputs localLib; };
  src =
    let getDrv = x:
      if pkgs.lib.isDerivation x then [ x ]
      else if builtins.isAttrs x then builtins.concatMap getDrv (builtins.attrValues x)
      else if builtins.isList x then builtins.concatMap getDrv x
      else [];
    in pkgs.writeText "src" (builtins.concatStringsSep "\n" (getDrv inputs.self.outputs.src));
  dns-push = pkgs.callPackage ./dns
  {
    inherit localLib;
    tokenPath = inputs.self.nixosConfigurations.pc.config.nixos.system.sops.secrets."acme/token".path;
    octodns = pkgs.octodns.withProviders (_: with pkgs.octodns-providers; [ cloudflare ]);
  };
  archive =
    let
      systemWithBuildDeps = system:
        (system.extendModules { modules = [{ config.system.includeBuildDependencies = true; }]; })
          .config.system.build.toplevel;
      systems = inputs.nixpkgs.lib.mapAttrs (_: v: systemWithBuildDeps v) inputs.self.outputs.nixosConfigurations;
      inputListFile = pkgs.writeText "input-list"
        (builtins.concatStringsSep "\n" (builtins.attrValues inputs));
      archive = pkgs.writeText "archive" (builtins.concatStringsSep "\n"
        ((builtins.attrValues systems) ++ [ src inputListFile ]));
    in
    archive // { passthru = archive.passthru // systems // { inherit src; inputs = inputListFile; }; };
}
// (builtins.mapAttrs (_: v: v.config.system.build.toplevel) inputs.self.outputs.nixosConfigurations)
