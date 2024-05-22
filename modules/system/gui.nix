inputs:
{
  options.nixos.system.gui = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    preferred = mkOption { type = types.bool; default = inputs.config.nixos.system.gui.enable; };
    autoStart = mkOption { type = types.bool; default = inputs.config.nixos.system.gui.preferred; };
  };
  config =
    let
      inherit (builtins) map;
      inherit (inputs.lib) mkIf;
      inherit (inputs.config.nixos.system) gui;
    in mkIf gui.enable
    {
      services =
      {
        displayManager = { sddm.enable = true; defaultSession = "plasma"; };
        desktopManager.plasma6.enable = true;
        xserver.enable = true;
      };
      systemd.services.display-manager.enable = gui.autoStart;
      environment =
      {
        sessionVariables."GTK_USE_PORTAL" = "1";
        plasma6.excludePackages = inputs.lib.mkIf (!gui.preferred) [ inputs.pkgs.kdePackages.plasma-nm ];
      };
      xdg.portal.extraPortals = map (p: inputs.pkgs."xdg-desktop-portal-${p}") [ "gtk" "kde" "wlr" ];
      i18n.inputMethod =
      {
        enabled = "fcitx5";
        fcitx5.addons = map (p: inputs.pkgs."fcitx5-${p}") [ "rime" "chinese-addons" "mozc" "nord" "material-color" ];
      };
      programs = { dconf.enable = true; xwayland.enable = true; };
    };
}
