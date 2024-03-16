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
      topInputs.nix-flatpak.nixosModules.nix-flatpak
      (inputs:
      {
        config =
        {
          nixpkgs.overlays =
          [
            topInputs.qchem.overlays.default
            topInputs.nixd.overlays.default
            topInputs.napalm.overlays.default
            topInputs.pnpm2nix-nzbr.overlays.default
            topInputs.aagl.overlays.default
            (final: prev:
            {
              nix-vscode-extensions = topInputs.nix-vscode-extensions.extensions."${prev.system}";
              nur-xddxdd = topInputs.nur-xddxdd.overlays.default final prev;
              nur-linyinfeng = (topInputs.nur-linyinfeng.overlays.default final prev).linyinfeng;
              deploy-rs =
                { inherit (prev) deploy-rs; inherit ((topInputs.deploy-rs.overlay final prev).deploy-rs) lib; };
              # needed by mirism
              "nghttp2-23.05" =
                inputs.pkgs.callPackage "${inputs.topInputs."nixpkgs-23.05"}/pkgs/development/libraries/nghttp2" {};
              firefox-addons = (import "${topInputs.rycee}" { inherit (prev) pkgs; }).firefox-addons;
            })
          ];
          home-manager.sharedModules =
          [
            topInputs.plasma-manager.homeManagerModules.plasma-manager
            topInputs.nix-doom-emacs.hmModule
          ];
        };
      })
      ./hardware ./packages ./system ./virtualization ./services ./bugs ./users
    ];
  }
