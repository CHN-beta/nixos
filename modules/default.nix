inputs: let inherit (inputs) topInputs; in
{
  imports = inputs.localLib.mkModules
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
    { config.home-manager.sharedModules =
    [
      topInputs.catppuccin.homeModules.catppuccin
      topInputs.dankmaterialshell.homeModules.dankMaterialShell.default
      topInputs.dankmaterialshell.homeModules.dankMaterialShell.niri
    ];}
  ] ++ (inputs.localLib.findModules ./.);
}
