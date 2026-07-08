{ lib, flakeInputs, ... }:
{
  imports =
    lib.mkModules [
      flakeInputs.home-manager.nixosModules.home-manager
      flakeInputs.sops-nix.nixosModules.sops
      flakeInputs.nix-index-database.nixosModules.nix-index
      flakeInputs.impermanence.nixosModules.impermanence
      flakeInputs.nix-flatpak.nixosModules.nix-flatpak
      flakeInputs.catppuccin.nixosModules.catppuccin
      flakeInputs.nixvirt.nixosModules.default
      flakeInputs.harmonia.nixosModules.harmonia
      flakeInputs.dms-plugin-registry.modules.default
      flakeInputs.hermes.nixosModules.default
      {
        config.home-manager.sharedModules = [
          flakeInputs.catppuccin.homeModules.catppuccin
          flakeInputs.dms-plugin-registry.modules.default
        ];
      }
    ]
    ++ (lib.findModules ./.);
}
