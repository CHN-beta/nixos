inputs: let inherit (inputs) topInputs; in
{
  imports = inputs.localLib.mkModules
  [
    topInputs.home-manager.nixosModules.home-manager
    topInputs.sops-nix.nixosModules.sops
    topInputs.nix-index-database.nixosModules.nix-index
    topInputs.impermanence.nixosModules.impermanence
    topInputs.nix-flatpak.nixosModules.nix-flatpak
    topInputs.chaotic.nixosModules.default
    { config.chaotic.nyx.overlay.onTopOf = "user-pkgs"; }
    topInputs.catppuccin.nixosModules.catppuccin
    topInputs.aagl.nixosModules.default
    (inputs:
    {
      config =
      {
        nixpkgs.overlays =
        [
          topInputs.qchem.overlays.default
          topInputs.bscpkgs.overlays.default
          topInputs.aagl.overlays.default
          topInputs.nur-xddxdd.overlays.inSubTree
          (final: prev:
          {
            nix-vscode-extensions = topInputs.nix-vscode-extensions.extensions.${prev.system};
            nur-linyinfeng = (topInputs.nur-linyinfeng.overlays.default final prev).linyinfeng;
            firefox-addons = (import "${topInputs.rycee}" { inherit (prev) pkgs; }).firefox-addons;
            inherit (import topInputs.gricad { pkgs = final; }) intel-oneapi intel-oneapi-2022;
            linuxPackages_cachyos_lts =
              final.linuxPackagesFor (topInputs.cachyos-lts.overlays.default final prev).linuxPackages_cachyos;
          })
        ];
        home-manager.sharedModules =
        [
          topInputs.plasma-manager.homeManagerModules.plasma-manager
          topInputs.catppuccin.homeManagerModules.catppuccin
        ];
      };
    })
  ] ++ (inputs.localLib.findModules ./.);
}
