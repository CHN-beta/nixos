inputs:
{
  options.nixos.system.gui = let inherit (inputs.lib) mkOption types; in
  {
    implementation = mkOption { type = types.enum [ "kde" "niri" ]; default = "kde"; };
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
              "${inputs.pkgs.tuigreet}/bin/tuigreet"
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
        fcitx5.addons = with inputs.pkgs;
          [ qt6Packages.fcitx5-chinese-addons fcitx5-mozc fcitx5-material-color fcitx5-gtk ];
      };
      programs.dconf.enable = true;
      nixos.user.sharedModules = [(hmInputs:
      {
        config =
        {
          gtk =
          {
            enable = true;
            theme.name = "Breeze";
            gtk2 =
            {
              extraConfig = ''gtk-im-module="fcitx"'';
              configLocation = "${hmInputs.config.xdg.configHome}/gtk-2.0/gtkrc";
              force = true;
            };
            gtk3.extraConfig.gtk-im-module = "fcitx";
            gtk4.extraConfig.gtk-im-module = "fcitx";
          };
        };
      })];
    })
    # niri
    (inputs.lib.mkIf (gui.implementation == "niri")
    {
      programs.niri.enable = true;
      nixos.user.sharedModules = [(hmInputs:
      {
        config.programs.dankMaterialShell = { enable = true; niri.enableKeybinds = true; systemd.enable = true; };
      })];
      # niri module will auto enable this, disable it to avoid conflict with system ssh-agent and kwallet
      services.gnome = { gcr-ssh-agent.enable = false; gnome-keyring.enable = inputs.lib.mkForce false; };
    })
    # niri setup kwallet
    (inputs.lib.mkIf (gui.implementation == "niri")
    {
      nixos.packages.packages._packages = with inputs.pkgs.kdePackages; [ kwallet kwalletmanager kwallet-pam ];
      xdg.portal.extraPortals = [ inputs.pkgs.kdePackages.kwallet ];
      security.pam.services.login.kwallet = { enable = true; package = inputs.pkgs.kdePackages.kwallet-pam; };
      services.dbus.packages = inputs.lib.singleton
        (inputs.pkgs.writeTextDir "share/dbus-1/services/org.freedesktop.secrets.service"
        ''
          [D-BUS Service]
          Name=org.freedesktop.secrets
          Exec=${inputs.pkgs.kdePackages.kwallet}/bin/kwalletd6
        '');
    })
  ];
}
