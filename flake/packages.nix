{ inputs, localLib }: rec
{
  pkgs = (import inputs.nixpkgs
  {
    system = "x86_64-linux";
    config.allowUnfree = true;
    overlays = [ inputs.self.overlays.default ];
  });
  hpcstat =
    let
      openssh = (pkgs.pkgsStatic.openssh.override { withLdns = false; etcDir = null; }).overrideAttrs
        (prev: { doCheck = false; patches = prev.patches ++ [ ../packages/hpcstat/openssh.patch ];});
      duc = pkgs.pkgsStatic.duc.override { enableCairo = false; cairo = null; pango = null; };
      glaze = pkgs.pkgsStatic.glaze.overrideAttrs
        (prev: { cmakeFlags = prev.cmakeFlags ++ [ "-Dglaze_ENABLE_FUZZING=OFF" ]; });
      # pkgsStatic.clangStdenv have a bug
      # https://github.com/NixOS/nixpkgs/issues/177129
      biu = pkgs.pkgsStatic.localPackages.biu.override { stdenv = pkgs.pkgsStatic.gcc14Stdenv; inherit glaze; };
    in pkgs.pkgsStatic.localPackages.hpcstat.override
    {
      inherit openssh duc biu;
      standalone = true;
      version = inputs.self.rev or "dirty";
      stdenv = pkgs.pkgsStatic.gcc14Stdenv;
    };
  inherit (pkgs.localPackages) blog;
  inherit (pkgs.localPackages.pkgsStatic) chn-bsub;
  vaspberry = pkgs.pkgsStatic.localPackages.vaspberry.override
  {
    gfortran = pkgs.pkgsStatic.gfortran;
    lapack = pkgs.pkgsStatic.openblas;
  };
  jykang = import ../devices/jykang.xmuhpc inputs;
  src =
    let getDrv = x:
      if pkgs.lib.isDerivation x then [ x ]
      else if builtins.isAttrs x then builtins.concatMap getDrv (builtins.attrValues x)
      else if builtins.isList x then builtins.concatMap getDrv x
      else [];
    in pkgs.writeClosure (getDrv (inputs.self.outputs.src));
  dns-push = pkgs.callPackage ./dns
  {
    inherit localLib;
    tokenPath = inputs.self.nixosConfigurations.pc.config.sops.secrets."acme/token".path;
    octodns = pkgs.octodns.withProviders (_: with pkgs.octodns-providers; [ cloudflare ]);
  };
}
// (builtins.listToAttrs (builtins.map
  (system: { inherit (system) name; value = system.value.config.system.build.toplevel; })
  (localLib.attrsToList inputs.self.outputs.nixosConfigurations)))
