{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.nixos.model.variant == "desktop") {
    services = {
      greetd = {
        enable = true;
        settings.default_session.command =
          let
            sessionData = "${config.services.displayManager.sessionData.desktops}/share";
          in
          builtins.concatStringsSep " " [
            "${pkgs.tuigreet}/bin/tuigreet"
            "--sessions ${sessionData}/wayland-sessions --xsessions ${sessionData}/xsessions"
            "--time --asterisks --remember --remember-user-session"
          ];
      };
      # niri module will auto enable this, disable it to avoid conflict with system ssh-agent
      gnome.gcr-ssh-agent.enable = false;
      iio-niri.enable = true;
      # TODO: enable it in next release
      clight.enable = false;
    };
    environment = {
      sessionVariables = {
        GTK_USE_PORTAL = "1";
        # let electron use gnome keyring https://github.com/electron/electron/issues/39789#issuecomment-3433810585
        GNOME_DESKTOP_SESSION_ID = "this-is-deprecated";
      };
      persistence."/nix/persistent".directories = [
        {
          directory = "/var/cache/tuigreet";
          user = "greeter";
          group = "greeter";
          mode = "0700";
        }
      ];
      systemPackages = with pkgs; [
        # nautilus is needed before we use implementation from nixpkgs
        nautilus
        # needed for xwayland
        xwayland-satellite
        # needed for icons
        adwaita-icon-theme
        # voice input
        voxtype-onnx
        # manually adjust brightness and media play
        playerctl
        brightnessctl
      ];
    };
    xdg.portal.extraPortals = (
      builtins.map (p: pkgs."xdg-desktop-portal-${p}") [
        "gtk"
        "wlr"
        "gnome"
      ]
    );
    qt = {
      enable = true;
      platformTheme = "qt5ct";
    };
    gtk.iconCache.enable = true;
    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5.addons = with pkgs; [
        qt6Packages.fcitx5-chinese-addons
        fcitx5-mozc
        fcitx5-material-color
        fcitx5-gtk
      ];
    };
    programs = {
      dconf.enable = true;
      niri.enable = true;
      dms-shell = {
        enable = true;
        plugins = {
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
    };
    nixos.user.sharedModules = [
      (hmInputs: {
        config = {
          systemd.user.services.voxtype = {
            Unit = {
              PartOf = [ "graphical-session.target" ];
              After = [ "graphical-session.target" ];
            };
            Service = {
              type = "simple";
              ExecStart = "${pkgs.voxtype-onnx}/bin/voxtype";
              Restart = "on-failure";
              RestartSec = "5s";
            };
            Install.WantedBy = [ "graphical-session.target" ];
          };
          xdg.configFile."niri/config.kdl".source = ./config.kdl;
        };
      })
    ];
    systemd.user.services = {
      # use polkit from dms
      niri-flake-polkit.enable = false;
      # iio-niri retry when failed
      iio-niri.serviceConfig = {
        RestartSec = 5;
        StartLimitIntervalSec = 0;
      };
    };
    location.provider = "geoclue2";
  };
}
