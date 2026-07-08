{ lib, self, ... }:
{
  imports =
    lib.mkModules [
      self.inputs.home-manager.nixosModules.home-manager
      self.inputs.sops-nix.nixosModules.sops
      self.inputs.nix-index-database.nixosModules.nix-index
      self.inputs.impermanence.nixosModules.impermanence
      self.inputs.nix-flatpak.nixosModules.nix-flatpak
      self.inputs.catppuccin.nixosModules.catppuccin
      self.inputs.nixvirt.nixosModules.default
      self.inputs.harmonia.nixosModules.harmonia
      self.inputs.dms-plugin-registry.modules.default
      self.inputs.hermes.nixosModules.default
      {
        config.home-manager.sharedModules = [
          self.inputs.catppuccin.homeModules.catppuccin
          self.inputs.dms-plugin-registry.modules.default
        ];
      }
    ]
    ++ (lib.findModules ./.);
}
