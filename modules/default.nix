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
    topInputs.nixvirt.nixosModules.default
    topInputs.niri.nixosModules.niri
    { config.niri-flake.cache.enable = false; }
    # TODO: Remove after next release
    "${topInputs.nixpkgs-unstable}/nixos/modules/services/hardware/lact.nix"
    (inputs:
    {
      config =
      {
        home-manager.sharedModules =
        [
          topInputs.plasma-manager.homeModules.plasma-manager
          topInputs.catppuccin.homeModules.catppuccin
        ];
      };
    })
  ] ++ (inputs.localLib.findModules ./.);
}
