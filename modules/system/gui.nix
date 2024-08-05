inputs:
{
  options.nixos.system.gui = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    preferred = mkOption { type = types.bool; default = inputs.config.nixos.system.gui.enable; };
    autoStart = mkOption { type = types.bool; default = inputs.config.nixos.system.gui.preferred; };
  };
  config = let inherit (inputs.config.nixos.system) gui; in inputs.lib.mkIf gui.enable
  {
    services =
    {
      displayManager =
      {
        sddm = { enable = inputs.lib.mkDefault true; wayland.enable = true; theme = "breeze"; };
        defaultSession = "plasma";
      };
      desktopManager.plasma6.enable = true;
      xserver.enable = true;
    };
    systemd.services.display-manager.enable = inputs.lib.mkDefault gui.autoStart;
    environment =
    {
      sessionVariables =
      {
        GTK_USE_PORTAL = "1";
        NIXOS_OZONE_WL = inputs.lib.mkIf gui.preferred "1";
      };
      plasma6.excludePackages = inputs.lib.mkIf (!gui.preferred) [ inputs.pkgs.kdePackages.plasma-nm ];
      persistence = let inherit (inputs.config.nixos.system) impermanence; in inputs.lib.mkIf impermanence.enable
      {
        "${impermanence.root}".directories =
          [{ directory = "/var/lib/sddm"; user = "sddm"; group = "sddm"; mode = "0700"; }];
      };
    };
    xdg.portal.extraPortals = builtins.map (p: inputs.pkgs."xdg-desktop-portal-${p}") [ "gtk" "wlr" ];
    i18n.inputMethod =
    {
      enable = true;
      type = "fcitx5";
      fcitx5.addons = builtins.map (p: inputs.pkgs."fcitx5-${p}")
        [ "rime" "chinese-addons" "mozc" "nord" "material-color" ];
    };
    programs.dconf.enable = true;
  };
}
