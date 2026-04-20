{ inputs, localLib }: rec
{
  pkgs = import inputs.nixpkgs (localLib.buildNixpkgsConfig
  {
    inputs = { inherit (inputs.nixpkgs) lib; flakeInputs = inputs; };
    nixpkgs = { march = null; nixos = false; };
  });
  inherit (pkgs.localPkgs.pkgsStatic) chn-bsub;
  vaspberry = pkgs.pkgsStatic.localPkgs.vaspberry.override
  {
    gfortran = pkgs.pkgsStatic.gfortran;
    lapack = pkgs.pkgsStatic.openblas;
  };
  xmuhk = import ../devices/xmuhk { inherit inputs localLib; };
  xmuhpc = import ../devices/xmuhpc { inherit inputs localLib; };
  src =
    let getDrv = x:
      if pkgs.lib.isDerivation x then [ x ]
      else if builtins.isAttrs x then builtins.concatMap getDrv (builtins.attrValues x)
      else if builtins.isList x then builtins.concatMap getDrv x
      else [];
    in pkgs.writeText "src" (builtins.concatStringsSep "\n" (getDrv inputs.self.outputs.src));
  dns-push = pkgs.callPackage ./dns
  {
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
  inherit (pkgs.pkgsCross.ucrt64.localPkgs) xinli;
}
// (builtins.mapAttrs (_: v: v.config.system.build.toplevel) inputs.self.outputs.nixosConfigurations)
