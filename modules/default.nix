{ localLib, flakeInputs, ... }:
{
  imports = localLib.mkModules
  [
    flakeInputs.home-manager.nixosModules.home-manager
    flakeInputs.sops-nix.nixosModules.sops
    flakeInputs.nix-index-database.nixosModules.nix-index
    flakeInputs.impermanence.nixosModules.impermanence
    flakeInputs.nix-flatpak.nixosModules.nix-flatpak
    flakeInputs.catppuccin.nixosModules.catppuccin
    flakeInputs.aagl.nixosModules.default
    flakeInputs.nixvirt.nixosModules.default
    flakeInputs.niri.nixosModules.niri
    { config.niri-flake.cache.enable = false; }
    flakeInputs.harmonia.nixosModules.harmonia
    flakeInputs.dms-plugin-registry.modules.default
    { config.home-manager.sharedModules =
    [
      flakeInputs.catppuccin.homeModules.catppuccin
      flakeInputs.dankmaterialshell.homeModules.dank-material-shell
      flakeInputs.dankmaterialshell.homeModules.niri
      flakeInputs.dms-plugin-registry.modules.default
    ];}
  ] ++ (localLib.findModules ./.);
}
