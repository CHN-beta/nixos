{ lib, config, pkgs, ... }:
{
  config = lib.mkIf (config.nixos.model.type == "desktop")
  {
    services =
    {
      greetd =
      {
        enable = true;
        settings.default_session.command =
          let sessionData = "${config.services.displayManager.sessionData.desktops}/share";
          in builtins.concatStringsSep " "
          [
            "${pkgs.tuigreet}/bin/tuigreet"
            "--sessions ${sessionData}/wayland-sessions --xsessions ${sessionData}/xsessions"
            "--time --asterisks --remember --remember-user-session"
          ];
      };
      # niri module will auto enable this, disable it to avoid conflict with system ssh-agent
      gnome.gcr-ssh-agent.enable = false;
      iio-niri.enable = true;
      clight.enable = true;
    };
    environment =
    {
      sessionVariables =
      {
        GTK_USE_PORTAL = "1";
        # let electron use gnome keyring https://github.com/electron/electron/issues/39789#issuecomment-3433810585
        GNOME_DESKTOP_SESSION_ID = "this-is-deprecated";
        QT_QPA_PLATFORMTHEME = "gtk3";
      };
      persistence."/nix/persistent".directories =
        [{ directory = "/var/cache/tuigreet"; user = "greeter"; group = "greeter"; mode = "0700"; }];
      systemPackages = with pkgs;
      [
        # nautilus is needed before we use implementation from nixpkgs
        nautilus
        # needed for xwayland
        xwayland-satellite
        # needed for icons
        adwaita-icon-theme
        # voice input
        pkgs-unstable.voxtype-vulkan
      ];
    };
    xdg.portal.extraPortals = (builtins.map (p: pkgs."xdg-desktop-portal-${p}") [ "gtk" "wlr" "gnome" ]);
    qt.enable = true;
    gtk.iconCache.enable = true;
    i18n.inputMethod =
    {
      enable = true;
      type = "fcitx5";
      fcitx5.addons = with pkgs;
      [
        qt6Packages.fcitx5-chinese-addons fcitx5-mozc fcitx5-material-color fcitx5-gtk
      ];
    };
    programs = { dconf.enable = true; niri.enable = true; };
    nixos.user.sharedModules = [(hmInputs:
    {
      config =
      {
        programs =
        {
          dank-material-shell =
          {
            enable = true;
            niri.enableKeybinds = true;
            systemd = { enable = true; restartIfChanged = true; };
            dgop.package = pkgs.pkgs-unstable.dgop;
            plugins =
            {
              dankPomodoroTimer.enable = true;
              amdGpuMonitor.enable = true;
              displayManager.enable = true;
              aiAssistant.enable = true;
              alarmClock.enable = true;
              displayMirror.enable = true;
              # phoneConnect.enable = true;
              taskwarrior.enable = true;
              timeUntil.enable = true;
              vscodeLauncher.enable = true;
              voxtype.enable = true;
            };
          };
          niri =
          {
            package = pkgs.niri;
            settings =
            {
              binds =
                let
                  xsel = "${pkgs.xsel}/bin/xsel";
                  wl-copy = "${pkgs.wl-clipboard}/bin/wl-copy";
                  wl-paste = "${pkgs.wl-clipboard}/bin/wl-paste";
                in
                {
                  "Mod+WheelScrollDown" = { action.focus-column-right = {}; cooldown-ms = 50; };
                  "Mod+WheelScrollUp" = { action.focus-column-left = {}; cooldown-ms = 50; };
                  "Mod+Left".action.focus-column-left = {};
                  "Mod+Right".action.focus-column-right = {};
                  "Ctrl+Mod+Left".action.move-column-left = {};
                  "Ctrl+Mod+Right".action.move-column-right = {};
                  "Mod+Up".action.focus-workspace-up = {};
                  "Mod+Down".action.focus-workspace-down = {};
                  "Mod+MouseMiddle".action.close-window = {};
                  "Mod+L".action.spawn = [ "dms" "ipc" "lock" "lock" ];
                  "Mod+W".action.move-workspace-to-monitor-next = {};
                  "Mod+Ctrl+C".action.spawn = [ "sh" "-c" "${xsel} -ob | ${wl-copy}" ];
                  "Mod+Ctrl+V".action.spawn = [ "sh" "-c" "${wl-paste} -n | ${xsel} -ib" ];
                  "Mod+S".action.screenshot = {};
                  "Mod+F".action.switch-preset-column-width = {};
                  "Mod+T".action.spawn = [ "ghostty" ];
                  "Mod+B".action.spawn = [ "firefox" ];
                  "Mod+Y".action.spawn = [ "typora" ];
                  "Mod+Escape".action.power-off-monitors = {};
                  # TODO: remove after dms update
                  "XF86AudioPlay".action.spawn = [ "dms" "ipc" "call" "mpris" "playPause" ];
                  "XF86Launch3".action.spawn = [ "voxtype" "record" "toggle" ];
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
              input =
              {
                touchpad.dwt = true;
                keyboard.numlock = true;
                power-key-handling.enable = false;
                focus-follows-mouse = { enable = true; max-scroll-amount="10%"; };
              };
              layout =
              {
                default-column-width.proportion = 0.5;
                preset-column-widths = [ { proportion = 0.5; } { proportion = 1.; } ];
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
        };
        systemd.user.services.voxtype =
        {
          Unit = { PartOf = [ "graphical-session.target" ]; After = [ "graphical-session.target" ]; };
          Service =
          {
            type = "simple";
            ExecStart = "${pkgs.pkgs-unstable.voxtype-vulkan}/bin/voxtype";
            Restart = "on-failure";
            RestartSec = "5s";
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };
      };
    })];
    systemd.user.services =
    {
      # use polkit from dms
      niri-flake-polkit.enable = false;
      # iio-niri retry when failed
      iio-niri.serviceConfig = { RestartSec = 5; StartLimitIntervalSec = 0; };
    };
    location.provider = "geoclue2";
  };
}
