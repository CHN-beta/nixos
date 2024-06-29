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
      topInputs.nur-xddxdd.nixosModules.setupOverlay
      topInputs.impermanence.nixosModules.impermanence
      topInputs.nix-flatpak.nixosModules.nix-flatpak
      topInputs.chaotic.nixosModules.default
      { config.chaotic.nyx.overlay.onTopOf = "user-pkgs"; }
      topInputs.catppuccin.nixosModules.catppuccin
      (inputs:
      {
        config =
        {
          nixpkgs.overlays =
          [
            topInputs.qchem.overlays.default
            topInputs.aagl.overlays.default
            topInputs.bscpkgs.overlays.default
            (final: prev:
            {
              nix-vscode-extensions = topInputs.nix-vscode-extensions.extensions."${prev.system}";
              nur-xddxdd = topInputs.nur-xddxdd.overlays.default final prev;
              nur-linyinfeng = (topInputs.nur-linyinfeng.overlays.default final prev).linyinfeng;
              firefox-addons = (import "${topInputs.rycee}" { inherit (prev) pkgs; }).firefox-addons;
              inherit (import topInputs.gricad { pkgs = final; }) intel-oneapi intel-oneapi-2022;
            })
          ];
          home-manager.sharedModules =
          [
            topInputs.plasma-manager.homeManagerModules.plasma-manager
            topInputs.catppuccin.homeManagerModules.catppuccin
          ];
        };
      })
      ./hardware ./packages ./system ./virtualization ./services ./bugs ./user
    ];
  }
