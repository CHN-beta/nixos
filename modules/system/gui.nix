inputs:
{
  options.nixos.system.gui = let inherit (inputs.lib) mkOption types; in
  {
    implementation = mkOption { type = types.enum [ "kde" ]; default = "kde"; };
  };
  config = let inherit (inputs.config.nixos.system) gui; in inputs.lib.mkMerge
  [
    # enable gui
    (inputs.lib.mkIf (inputs.config.nixos.model.type == "desktop")
    {
      services =
      {
        desktopManager.plasma6.enable = inputs.lib.mkIf (gui.implementation == "kde") true;
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
              (inputs.lib.optionalString (gui.implementation == "kde") "--cmd startplasma-wayland")
            ];
        };
      };
      environment =
      {
        sessionVariables.GTK_USE_PORTAL = "1";
        persistence."/nix/persistent".directories =
          [{ directory = "/var/cache/tuigreet"; user = "greeter"; group = "greeter"; mode = "0700"; }];
      };
      xdg.portal.extraPortals = (builtins.map (p: inputs.pkgs."xdg-desktop-portal-${p}") [ "gtk" "wlr" ])
        ++ [ inputs.pkgs.kdePackages.xdg-desktop-portal-kde ];
      i18n.inputMethod =
      {
        enable = true;
        type = "fcitx5";
        fcitx5.addons = builtins.map (p: inputs.pkgs."fcitx5-${p}") [ "chinese-addons" "mozc" "material-color" "gtk" ];
      };
      programs.dconf.enable = true;
      nixos.user.sharedModules = [(hmInputs:
      {
        config.gtk =
        {
          enable = true;
          gtk2 =
          {
            extraConfig = ''gtk-im-module="fcitx"'';
            configLocation = "${hmInputs.config.xdg.configHome}/gtk-2.0/gtkrc";
          };
          gtk3.extraConfig.gtk-im-module = "fcitx";
          gtk4.extraConfig.gtk-im-module = "fcitx";
        };
      })];
    })
    # prefer gui or not
    (inputs.localLib.mkConditional (builtins.elem inputs.config.nixos.model.type [ "desktop" ])
      { environment.sessionVariables.NIXOS_OZONE_WL = "1"; }
      {
        environment.plasma6.excludePackages = inputs.lib.mkIf (gui.implementation == "kde")
          [ inputs.pkgs.kdePackages.plasma-nm ];
      })
  ];
}
