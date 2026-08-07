{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.nixos.system.gui = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.submodule {
        options = {
          implementation = lib.mkOption {
            type = lib.types.enum [
              "niri"
              "kde"
            ];
            default = "niri";
          };
        };
      }
    );
    default = if config.nixos.model.variant == "desktop" then { } else null;
  };
  config = lib.mkIf (config.nixos.system.gui != null) (
    let
      inherit (config.nixos.system) gui;
    in
    lib.mkMerge [
      # Common GUI settings
      {
        environment = {
          sessionVariables.GTK_USE_PORTAL = "1";
          systemPackages = with pkgs; [
            voxtype-onnx
          ];
        };
        xdg.portal.extraPortals = (
          builtins.map (p: pkgs."xdg-desktop-portal-${p}") [
            "gtk"
            "wlr"
            "gnome"
          ]
        );
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
        programs.dconf.enable = true;
        location.provider = "geoclue2";
      }

      # Niri implementation
      (lib.mkIf (gui.implementation == "niri") {
        services = {
          xserver.xkb = {
            layout = "custom_nav";
            extraLayouts."custom_nav" = {
              description = "Custom layout with Right Ctrl as Navigation modifier";
              languages = [ "eng" ];
              symbolsFile = pkgs.writeText "custom-xkb-symbols" ''
                xkb_symbols "right_ctrl_nav" {
                    include "us(basic)"
                    key <RCTL> { [ ISO_Level3_Shift ] };
                    modifier_map Mod5 { ISO_Level3_Shift };
                    key <UP>   { 
                        type= "FOUR_LEVEL",
                        symbols[Group1]= [ Up, Up, Prior, Prior ] 
                    };
                    key <DOWN> { 
                        type= "FOUR_LEVEL",
                        symbols[Group1]= [ Down, Down, Next, Next ] 
                    };
                    key <LEFT> { 
                        type= "FOUR_LEVEL",
                        symbols[Group1]= [ Left, Left, Home, Home ] 
                    };
                    key <RGHT> { 
                        type= "FOUR_LEVEL",
                        symbols[Group1]= [ Right, Right, End, End ] 
                    };
                };
              '';
            };
          };
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
          # let electron use gnome keyring https://github.com/electron/electron/issues/39789#issuecomment-3433810585
          sessionVariables.GNOME_DESKTOP_SESSION_ID = "this-is-deprecated";
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
            # manually adjust brightness and media play
            playerctl
            brightnessctl
          ];
        };
        qt = {
          enable = true;
          platformTheme = "qt5ct";
        };
        programs = {
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
              services.voxtype = {
                enable = true;
                package = pkgs.voxtype-onnx;
                settings = {
                  audio = {
                    device = "default";
                    feedback.enabled = true;
                    max_duration_secs = 60;
                    sample_rate = 16000;
                  };
                  engine = "sensevoice";
                  hotkey.enabled = false;
                  output = {
                    fallback_to_clipboard = true;
                    mode = "clipboard";
                    notification = {
                      on_recording_start = false;
                      on_recording_stop = false;
                      on_transcription = false;
                    };
                    type_delay_ms = 50;
                  };
                  sensevoice = {
                    language = "auto";
                    model = "small";
                    use_itn = true;
                  };
                  state_file = "auto";
                };
              };
              systemd.user.services.voxtype = {
                Unit = {
                  PartOf = lib.mkForce [ "graphical-session.target" ];
                  After = lib.mkForce [ "graphical-session.target" ];
                };
                Install.WantedBy = lib.mkForce [ "graphical-session.target" ];
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
      })
      # KDE implementation
      (lib.mkIf (gui.implementation == "kde") {
        services = {
          displayManager.sddm = {
            enable = true;
            wayland.enable = true;
            autoNumlock = true;
          };
          desktopManager.plasma6.enable = true;
        };
        environment = {
          etc."xdg/baloofilerc".text = ''
            [Basic Settings]
            Indexing-Enabled=false
          '';
        };
      })
    ]
  );
}
