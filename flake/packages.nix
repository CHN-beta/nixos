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
    in pkgs.pkgsStatic.localPackages.hpcstat.override
      { inherit openssh duc; standalone = true; version = inputs.self.rev or "dirty"; };
  chn-bsub = pkgs.pkgsStatic.localPackages.chn-bsub;
  blog = pkgs.callPackage ../blog { inherit (inputs) hextra; };
}
// (builtins.listToAttrs (builtins.map
  (system: { inherit (system) name; value = system.value.config.system.build.toplevel; })
  (localLib.attrsToList inputs.self.outputs.nixosConfigurations)))
