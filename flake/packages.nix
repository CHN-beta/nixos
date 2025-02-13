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
  chn-bsub = pkgs.pkgsStatic.localPackages.chn-bsub;
  blog = pkgs.localPackages.blog;
  vaspberry = pkgs.pkgsStatic.localPackages.vaspberry.override
  {
    gfortran = pkgs.pkgsStatic.gfortran;
    lapack = pkgs.pkgsStatic.openblas;
  };
}
// (builtins.listToAttrs (builtins.map
  (system: { inherit (system) name; value = system.value.config.system.build.toplevel; })
  (localLib.attrsToList inputs.self.outputs.nixosConfigurations)))
