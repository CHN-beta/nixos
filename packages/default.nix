self: rec
{
  inherit (self.inputs.nixpkgs) lib;
  pkgs = import self.inputs.nixpkgs (self.lib.buildNixpkgsConfig { march = null; nixos = false; });
  vaspberry = pkgs.pkgsStatic.localPkgs.vaspberry.override
  {
    gfortran = pkgs.pkgsStatic.gfortran;
    lapack = pkgs.pkgsStatic.openblas;
  };
  xmuhk = import ./xmuhk { inherit (self) inputs; inherit (self.lib) buildNixpkgsConfig; };
  xmuhpc = import ./xmuhpc { inherit (self) inputs; inherit (self.lib) buildNixpkgsConfig; };
  src =
    let getDrv = x:
      if lib.isDerivation x then [ x ]
      else if builtins.isAttrs x then builtins.concatMap getDrv (builtins.attrValues x)
      else if builtins.isList x then builtins.concatMap getDrv x
      else [];
    in pkgs.writeText "src" (builtins.concatStringsSep "\n" (getDrv self.outputs.src));
  dns-push = pkgs.callPackage ./dns
  {
    tokenPath = self.nixosConfigurations.pc.config.nixos.system.sops.secrets."acme/token".path;
    octodns = pkgs.octodns.withProviders (_: with pkgs.octodns-providers; [ cloudflare ]);
  };
  archive =
    let
      systems = self.outputs.nixosConfigurations
        |> lib.mapAttrs (_: v: v.extendModules { modules = [{ config.system.includeBuildDependencies = true; }]; })
        |> lib.mapAttrs (_: v: v.config.system.build.toplevel);
      inputListFile = self.inputs |> builtins.attrValues |> builtins.concatStringsSep "\n"
        |> pkgs.writeText "input-list";
    in (builtins.attrValues systems) ++ [ src inputListFile ]
      |> builtins.concatStringsSep "\n"
      |> pkgs.writeText "archive"
      |> lib.addMetaAttrs (systems // { inherit src; inputs = inputListFile; });
  inherit (pkgs.pkgsCross.ucrt64.localPkgs) xinli;
  inherit (pkgs.pkgsStatic.localPkgs) ufo;
  gsl = self.nixosConfigurations.pc.pkgs.gsl.overrideAttrs { src = self.inputs.gsl; doCheck = true; };
}
// (builtins.mapAttrs (_: v: v.config.system.build.toplevel) self.outputs.nixosConfigurations)
