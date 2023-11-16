inputs:
{
  options.nixos.system.gui = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    preferred = mkOption { type = types.bool; default = false; };
    autoStart = mkOption { type = types.bool; default = inputs.config.nixos.system.gui.preferred; };
  };
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.config.nixos.system) gui;
    in mkIf gui.enable
    {
      services.xserver =
      {
        enable = true;
        displayManager = { sddm.enable = true; defaultSession = "plasmawayland"; };
        desktopManager.plasma5.enable = true;
        videoDrivers = inputs.config.nixos.hardware.gpus;
      };
      systemd.services.display-manager = { after = [ "network-online.target" ]; enable = gui.autoStart; };
      environment =
      {
        sessionVariables."GTK_USE_PORTAL" = "1";
        plasma5.excludePackages = inputs.lib.mkIf (!gui.preferred) [ inputs.pkgs.plasma5Packages.plasma-nm ];
      };
      xdg.portal.extraPortals = map (p: inputs.pkgs."xdg-desktop-portal-${p}") [ "gtk" "kde" "wlr" ];
      i18n.inputMethod =
      {
        enabled = "fcitx5";
        fcitx5.addons = with inputs.pkgs; [ fcitx5-rime fcitx5-chinese-addons fcitx5-mozc ];
      };
      programs = { dconf.enable = true; xwayland.enable = true; };
    };
}
