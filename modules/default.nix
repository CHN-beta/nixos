inputs:
  let
    inherit (inputs) topInputs;
    inherit (inputs.localLib) mkModules;
  in
  {
    imports = mkModules
    [
      topInputs.home-manager.nixosModules.home-manager
      topInputs.sops-nix.nixosModules.sops
      topInputs.aagl.nixosModules.default
      topInputs.nix-index-database.nixosModules.nix-index
      topInputs.nur.nixosModules.nur
      topInputs.nur-xddxdd.nixosModules.setupOverlay
      topInputs.impermanence.nixosModules.impermanence
      (inputs: { config.nixpkgs.overlays =
      [
        topInputs.qchem.overlays.default
        topInputs.nixd.overlays.default
        topInputs.nix-alien.overlays.default
        topInputs.napalm.overlays.default
        topInputs.pnpm2nix-nzbr.overlays.default
        topInputs.lmix.overlays.default
        (import "${topInputs.dguibert-nur-packages}/overlays/nvhpc-overlay")
        (final: prev:
        {
          touchix = topInputs.touchix.packages."${prev.system}";
          nix-vscode-extensions = topInputs.nix-vscode-extensions.extensions."${prev.system}";
          nur-xddxdd = topInputs.nur-xddxdd.overlays.default final prev;
          deploy-rs = { inherit (prev) deploy-rs; inherit ((topInputs.deploy-rs.overlay final prev).deploy-rs) lib; };
        })
      ];})
      ./kernel ./hardware ./packages ./system ./virtualization ./services ./bugs ./users
    ];
  }
