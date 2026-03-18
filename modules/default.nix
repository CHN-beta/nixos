{ localLib, topInputs, ... }:
{
  imports = localLib.mkModules
  [
    topInputs.home-manager.nixosModules.home-manager
    topInputs.sops-nix.nixosModules.sops
    topInputs.nix-index-database.nixosModules.nix-index
    topInputs.impermanence.nixosModules.impermanence
    topInputs.nix-flatpak.nixosModules.nix-flatpak
    topInputs.catppuccin.nixosModules.catppuccin
    topInputs.aagl.nixosModules.default
    topInputs.nixvirt.nixosModules.default
    topInputs.niri.nixosModules.niri
    { config.niri-flake.cache.enable = false; }
    topInputs.harmonia.nixosModules.harmonia
    topInputs.dms-plugin-registry.modules.default
    { config.home-manager.sharedModules =
    [
      topInputs.catppuccin.homeModules.catppuccin
      topInputs.dankmaterialshell.homeModules.dank-material-shell
      topInputs.dankmaterialshell.homeModules.niri
      topInputs.dms-plugin-registry.modules.default
    ];}
  ] ++ (localLib.findModules ./.);
}
