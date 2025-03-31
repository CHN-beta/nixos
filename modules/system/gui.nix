inputs:
{
  config = inputs.lib.mkMerge
  [
    # enable gui
    (inputs.lib.mkIf (builtins.elem inputs.config.nixos.model.type [ "desktop" "server" ])
    {
      services =
      {
        desktopManager.plasma6.enable = true;
        xserver.enable = true;
        greetd =
        {
          enable = true;
          settings.default_session.command =
            let sessionData = "${inputs.config.services.displayManager.sessionData.desktops}/share";
            in builtins.concatStringsSep " "
            [
              "${inputs.pkgs.greetd.tuigreet}/bin/tuigreet"
              "--sessions ${sessionData}/wayland-sessions --xsessions ${sessionData}/xsessions"
              "--time --asterisks --remember --remember-user-session"
              "--cmd startplasma-wayland"
            ];
        };
      };
      environment =
      {
        sessionVariables.GTK_USE_PORTAL = "1";
        persistence."/nix/persistent".directories =
          [{ directory = "/var/cache/tuigreet"; user = "greeter"; group = "greeter"; mode = "0700"; }];
        systemPackages = with inputs.pkgs; [ waybar ];
      };
      xdg.portal.extraPortals = builtins.map (p: inputs.pkgs."xdg-desktop-portal-${p}") [ "gtk" "wlr" ];
      i18n.inputMethod =
      {
        enable = true;
        type = "fcitx5";
        fcitx5.addons = builtins.map (p: inputs.pkgs."fcitx5-${p}")
          [ "rime" "chinese-addons" "mozc" "nord" "material-color" ];
      };
      programs =
      {
        dconf.enable = true;
        hyprland = { enable = true; withUWSM = true; };
        # waybar should not be pull in by graphical-session.target
        waybar.enable = false;
        iio-hyprland.enable = true;
        hyprlock.enable = true;
        uwsm.enable = true;
      };
      systemd.services.display-manager.after = [ "plymouth-quit.service" ];
    })
    # prefer gui or not
    (inputs.localLib.mkConditional (builtins.elem inputs.config.nixos.model.type [ "desktop" ])
      { environment.sessionVariables.NIXOS_OZONE_WL = "1"; }
      { environment.plasma6.excludePackages = [ inputs.pkgs.kdePackages.plasma-nm ]; })
  ];
}
