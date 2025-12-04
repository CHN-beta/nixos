inputs:
{
  options.nixos.system.gui = let inherit (inputs.lib) mkOption types; in
  {
    implementation = mkOption { type = types.enum [ "kde" "niri" ]; default = "niri"; };
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
      xdg.portal.extraPortals = (builtins.map (p: inputs.pkgs."xdg-desktop-portal-${p}") [ "gtk" "wlr" "gnome" ])
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
    (inputs.lib.mkIf (inputs.config.nixos.model.type == "desktop" && gui.implementation == "niri")
    {
      programs.niri.enable = true;
      nixos.user.sharedModules = [(hmInputs:
      {
        config.programs =
        {
          dankMaterialShell =
          {
            enable = true;
            niri.enableKeybinds = true;
            systemd = { enable = true; restartIfChanged = true; };
          };
          niri.settings =
          {
            binds =
            {
              "Mod+WheelScrollDown" = { action.focus-column-right = {}; cooldown-ms = 50; };
              "Mod+WheelScrollUp" = { action.focus-column-left = {}; cooldown-ms = 50; };
              "Mod+Left".action.focus-column-left = {};
              "Mod+Right".action.focus-column-right = {};
              "Mod+MouseMiddle".action.close-window = {};
            };
            outputs =
            {
              "Tianma Microelectronics Ltd. TL134ADXP03 Unknown" = { scale = 1; position = { x = 0; y = 0; }; };
              "Xiaomi Corporation Mi Monitor 0x00000001" = { scale = 1; position = { x = 0; y = -2160; }; };
            };
            input.touchpad.dwt = true;
          };
        };
      })];
      # niri module will auto enable this, disable it to avoid conflict with system ssh-agent
      services.gnome.gcr-ssh-agent.enable = false;
      # use polkit from dms
      systemd.user.services.niri-flake-polkit.enable = false;
      environment =
      {
        # let electron use gnome keyring https://github.com/electron/electron/issues/39789#issuecomment-3433810585
        sessionVariables.GNOME_DESKTOP_SESSION_ID = "this-is-deprecated";
        systemPackages =
        [
          # nautilus is needed before we use implementation from nixpkgs
          inputs.pkgs.nautilus
          # needed for xwayland
          inputs.pkgs.xwayland-satellite
        ];
      };
    })
  ];
}
