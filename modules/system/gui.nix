inputs:
{
  config = inputs.lib.mkIf (inputs.config.nixos.model.type == "desktop")
  {
    services =
    {
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
          ];
      };
      # niri module will auto enable this, disable it to avoid conflict with system ssh-agent
      gnome.gcr-ssh-agent.enable = false;
    };
    environment =
    {
      sessionVariables =
      {
        GTK_USE_PORTAL = "1";
        # let electron use gnome keyring https://github.com/electron/electron/issues/39789#issuecomment-3433810585
        GNOME_DESKTOP_SESSION_ID = "this-is-deprecated";
      };
      persistence."/nix/persistent".directories =
        [{ directory = "/var/cache/tuigreet"; user = "greeter"; group = "greeter"; mode = "0700"; }];
      systemPackages =
      [
        # nautilus is needed before we use implementation from nixpkgs
        inputs.pkgs.nautilus
        # needed for xwayland
        inputs.pkgs.xwayland-satellite
      ];
    };
    xdg.portal.extraPortals = (builtins.map (p: inputs.pkgs."xdg-desktop-portal-${p}") [ "gtk" "wlr" "gnome" ]);
    qt = { enable = true; platformTheme = "qt5ct"; };
    i18n.inputMethod =
    {
      enable = true;
      type = "fcitx5";
      fcitx5.addons = with inputs.pkgs;
        [ qt6Packages.fcitx5-chinese-addons fcitx5-mozc fcitx5-material-color fcitx5-gtk ];
    };
    programs = { dconf.enable = true; niri.enable = true; };
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
            let
              xsel = "${inputs.pkgs.xsel}/bin/xsel";
              wl-copy = "${inputs.pkgs.wl-clipboard}/bin/wl-copy";
              wl-paste = "${inputs.pkgs.wl-clipboard}/bin/wl-paste";
            in
            {
              "Mod+WheelScrollDown" = { action.focus-column-right = {}; cooldown-ms = 50; };
              "Mod+WheelScrollUp" = { action.focus-column-left = {}; cooldown-ms = 50; };
              "Mod+Left".action.focus-column-left = {};
              "Mod+Right".action.focus-column-right = {};
              "Mod+MouseMiddle".action.close-window = {};
              "Mod+L".action.spawn = [ "dms" "ipc" "lock" "lock" ];
              "Mod+W".action.move-workspace-to-monitor-next = {};
              "Mod+Ctrl+C".action.spawn = [ "sh" "-c" "${xsel} -ob | ${wl-copy}" ];
              "Mod+Ctrl+V".action.spawn = [ "sh" "-c" "${wl-paste} -n | ${xsel} -ib" ];
              "Mod+S".action.screenshot = {};
              "Mod+F".action.set-column-width= "100%";
              "Mod+R".action.switch-preset-column-width = {};
              "Mod+T".action.expand-column-to-available-width = {};
            };
          outputs =
          {
            "Tianma Microelectronics Ltd. TL134ADXP03 Unknown" =
              { scale = 1; position = { x = 0; y = 0; }; mode = { width = 2560; height = 1600; refresh = 180.; }; };
            "Xiaomi Corporation Mi Monitor 0x00000001" =
            {
              scale = 1;
              position = { x = 0; y = -2160; };
              mode = { width = 3840; height = 2160; refresh = 160.; };
            };
          };
          input = { touchpad.dwt = true; keyboard.numlock = true; };
          layout =
          {
            default-column-width.proportion = 0.5;
            preset-column-widths = [ { proportion =  0.33333; } { proportion =  0.5; } { proportion =  0.66667; } ];
          };
          spawn-at-startup =
          [
            { argv = [ "Telegram" "-startintray" ]; }
            { argv = [ "steam" "-silent" ]; }
            { argv = [ "element-desktop" "--hidden" ]; }
            { argv = [ "discord" "--start-minimized" "--no-startup-id" ]; }
          ];
        };
      };
    })];
    # use polkit from dms
    systemd.user.services.niri-flake-polkit.enable = false;
  };
}
