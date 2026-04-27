{ inputs, localLib }: rec
{
  inherit (inputs.nixpkgs) lib;
  pkgs = import inputs.nixpkgs (localLib.buildNixpkgsConfig
  {
    inputs = { inherit (inputs.nixpkgs) lib; flakeInputs = inputs; };
    nixpkgs = { march = null; nixos = false; };
  });
  vaspberry = pkgs.pkgsStatic.localPkgs.vaspberry.override
  {
    gfortran = pkgs.pkgsStatic.gfortran;
    lapack = pkgs.pkgsStatic.openblas;
  };
  xmuhk = import ../devices/xmuhk { inherit inputs localLib; };
  xmuhpc = import ../devices/xmuhpc { inherit inputs localLib; };
  src =
    let getDrv = x:
      if lib.isDerivation x then [ x ]
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
      systems = inputs.self.outputs.nixosConfigurations
        |> lib.mapAttrs (_: v: v.extendModules { modules = [{ config.system.includeBuildDependencies = true; }]; })
        |> lib.mapAttrs (_: v: v.config.system.build.toplevel);
      inputListFile = inputs |> builtins.attrValues |> builtins.concatStringsSep "\n" |> pkgs.writeText "input-list";
    in (builtins.attrValues systems) ++ [ src inputListFile ]
      |> builtins.concatStringsSep "\n"
      |> pkgs.writeText "archive"
      |> lib.addMetaAttrs (systems // { inherit src; inputs = inputListFile; });
  inherit (pkgs.pkgsCross.ucrt64.localPkgs) xinli;
}
// (builtins.mapAttrs (_: v: v.config.system.build.toplevel) inputs.self.outputs.nixosConfigurations)
