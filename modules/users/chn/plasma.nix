inputs:
{
  config =
  {
    home-manager.users.chn.config =
    {
      programs.plasma = inputs.lib.mkMerge
      [
        # TODO: autostart, panel, discard user changed settings
        # general
        {
          enable = inputs.config.nixos.system.gui.enable;
          configFile.plasma-localerc = { Formats.LANG = "en_US.UTF-8"; Translations.LANGUAGE = "zh_CN"; };
          overrideConfig = true;
          overrideConfigFiles = [ "konsolerc" "yakuakerc" ];
        }
        # theme
        {
          workspace =
          {
            theme = "Fluent-round-light";
            colorScheme = "FluentLight";
            cursorTheme = "Breeze_Snow";
            lookAndFeel = "com.github.vinceliuice.Fluent-round-light";
            iconTheme = "breeze";
          };
          configFile =
          {
            kdeglobals.KDE.widgetStyle = "kvantum";
            "Kvantum/kvantum.kvconfig".General.theme = "Fluent-round";
            kwinrc =
            {
              Effect-blur.BlurStrength = 10;
              Effect-kwin4_effect_translucency.MoveResize = 75;
              Effect-wobblywindows = { AdvancedMode = true; Drag = 85; Stiffness = 10; WobblynessLevel = 1; };
              Plugins =
              {
                blurEnabled = true;
                kwin4_effect_dimscreenEnabled = true;
                kwin4_effect_translucencyEnabled = true;
                padding = 4;
                wobblywindowsEnabled = true;
              };
            };
          };
        }
        # shortcuts
        {
          spectacle.shortcuts.captureRectangularRegion = "Print";
          shortcuts = inputs.lib.mkMerge
          [
            # firefox
            { "firefox.desktop"._launch = "Meta+B"; }
            # crow translate
            { "io.crow_translate.CrowTranslate.desktop".TranslateSelectedText = "Ctrl+Alt+E"; }
            # display
            {
              kded5.display = [ "Display" "Meta+P" ];
              kwin = { view_actual_size = "Meta+0"; view_zoom_in = [ "Meta++" "Meta+=" ]; view_zoom_out = "Meta+-"; };
              org_kde_powerdevil =
              {
                "Decrease Screen Brightness" = "Monitor Brightness Down";
                "Increase Screen Brightness" = "Monitor Brightness Up";
              };
            }
            # volume
            {
              kmix =
              {
                decrease_volume = "Volume Down";
                increase_volume = "Volume Up";
                mic_mute = [ "Meta+Volume Mute" ];
                mute = "Volume Mute";
              };
            }
            # session
            {
              ksmserver = { "Lock Session" = [ "Meta+L" "Screensaver" ]; "Log Out" = "Ctrl+Alt+Del"; };
              org_kde_powerdevil."Turn Off Screen" = "Meta+Ctrl+L";
            }
            # window
            {
              kwin =
              {
                Overview = "Meta+Tab";
                "Show Desktop" = "Meta+D";
                "Suspend Compositing" = "Alt+Shift+F12";
                "Walk Through Windows" = "Alt+Tab";
                "Walk Through Windows (Reverse)" = "Alt+Shift+Backtab";
                "Window Above Other Windows" = "Meta+Shift+PgUp";
                "Window Below Other Windows" = "Meta+Shift+PgDown";
                "Window Close" = "Alt+F4";
                "Window Maximize" = "Meta+PgUp";
                "Window Minimize" = "Meta+PgDown";
                "Window Operations Menu" = "Alt+F3";
                "Window Quick Tile Bottom" = "Meta+Down";
                "Window Quick Tile Left" = "Meta+Left";
                "Window Quick Tile Right" = "Meta+Right";
                "Window Quick Tile Top" = "Meta+Up";
              };
            }
            # virtual desktop
            {
              kwin =
              {
                "Switch One Desktop Down" = "Meta+Ctrl+Down";
                "Switch One Desktop Up" = "Meta+Ctrl+Up";
                "Switch One Desktop to the Left" = "Meta+Ctrl+Left";
                "Switch One Desktop to the Right" = "Meta+Ctrl+Right";
                "Window One Desktop Down" = "Meta+Ctrl+Shift+Down";
                "Window One Desktop Up" = "Meta+Ctrl+Shift+Up";
                "Window One Desktop to the Left" = "Meta+Ctrl+Shift+Left";
                "Window One Desktop to the Right" = "Meta+Ctrl+Shift+Right";
              };
            }
            # media
            {
              mediacontrol =
              {
                nextmedia = "Media Next";
                pausemedia = "Media Pause";
                playpausemedia = [ "Pause" "Media Play" ];
                previousmedia = "Media Previous";
                stopmedia = "Media Stop";
              };
            }
            # dolphin
            { "org.kde.dolphin.desktop"._launch = "Meta+E"; }
            # konsole
            { "org.kde.konsole.desktop"._launch = "Ctrl+Alt+T"; }
            # krunner
            { "org.kde.krunner.desktop"._launch = "Alt+Space"; }
            # settings
            { "systemsettings.desktop"._launch = "Meta+I"; }
            # yakuake
            { yakuake.toggle-window-state = "Meta+Space"; }
            # virt-manager
            { "virt-manager.desktop"._launch = "Meta+V"; }
          ];
        }
        # kwin
        {
          kwin.titlebarButtons.right = [ "help" "keep-below-windows" "keep-above-windows" "minimize" "maximize" "close" ];
          windows.allowWindowsToRememberPositions = false;
          configFile =
          {
            plasmanotifyrc.Notifications.PopupPosition = "BottomRight";
            kwinrc =
            {
              Tiling.padding = 4;
              Wayland."InputMethod[$e]" = "/run/current-system/sw/share/applications/org.fcitx.Fcitx5.desktop";
              Windows.RollOverDesktops = true;
              Compositing = { AllowTearing = false; WindowsBlockCompositing = false; };
            };
          };
        }
        # baloo
        { configFile.baloofilerc."Basic Settings".Indexing-Enabled = false; }
        # dolphin and file chooser
        {
          configFile =
          {
            dolphinrc =
            {
              General = { ShowFullPath = true; FilterBar = true; RememberOpenedTabs = false; };
              PreviewSettings.Plugins = builtins.concatStringsSep ","
              [
                "blenderthumbnail"
                "comicbookthumbnail"
                "djvuthumbnail"
                "ebookthumbnail"
                "exrthumbnail"
                "marble_thumbnail_geojson"
                "marble_thumbnail_gpx"
                "jpegthumbnail"
                "marble_thumbnail_kmz"
                "marble_thumbnail_kml"
                "kraorathumbnail"
                "windowsimagethumbnail"
                "windowsexethumbnail"
                "mltpreview"
                "mobithumbnail"
                "opendocumentthumbnail"
                "marble_thumbnail_osm"
                "palathumbcreator"
                "gsthumbnail"
                "rawthumbnail"
                "svgthumbnail"
                "imagethumbnail"
                "fontthumbnail"
                "directorythumbnail"
                "textthumbnail"
                "webarchivethumbnail"
                "ffmpegthumbs"
                "audiothumbnail"
              ];
            };
            kdeglobals."KFileDialog Settings" =
            {
              "Allow Expansion" = true;
              "Automatically select filename extension" = true;
              "Show Bookmarks" = true;
              "Show Full Path" = true;
              "Show Inline Previews" = true;
              "Show Preview" = true;
              "Show Speedbar" = true;
              "Show hidden files" = true;
              "Sort by" = "Name";
              "Sort directories first" = true;
              "Sort hidden files last" = true;
              "View Style" = "DetailTree";
            };
          };
        }
        # krunner
        { configFile.krunnerrc = { General.FreeFloating = true; Plugins.baloosearchEnabled = false; }; }
        # lock screen
        { configFile.kscreenlockerrc.Daemon.Autolock = false; }
        # konsole and yakuake
        {
          configFile =
          {
            yakuakerc =
            {
              Appearance =
              {
                HideSkinBorders = true;
                Skin = "Slate";
                Translucency = true;
              };
              "Desktop Entry".DefaultProfile = "plasma-manager.profile";
              Dialogs.FirstRun = false;
              Window =
              {
                KeepOpen = false;
                KeepOpenAfterLastSessionCloses = true;
                ShowSystrayIcon = false;
              };
            };
            konsolerc =
            {
              "Desktop Entry".DefaultProfile = "plasma-manager.profile";
              "MainWindow.Toolbar sessionToolbar".ToolButtonStyle = "IconOnly";
            };
          };
          dataFile."konsole/plasma-manager.profile" =
          {
            Appearance =
            {
              AntiAliasFonts = true;
              BoldIntense = true;
              ColorScheme = "Breeze";
              Font = "FiraCode Nerd Font Mono,10,-1,5,50,0,0,0,0,0";
              UseFontLineChararacters = true;
              WordModeAttr = false;
            };
            "Cursor Options".CursorShape = 1;
            General =
            {
              Name = "plasma-manager";
              Parent = "FALLBACK/";
              TerminalCenter = true;
              TerminalMargin = 1;
            };
            "Interaction Options" =
            {
              AutoCopySelectedText = true;
              TrimLeadingSpacesInSelectedText = true;
              TrimTrailingSpacesInSelectedText = true;
              UnderlineFilesEnabled = true;
            };
            Scrolling =
            {
              HistoryMode = 2;
              ReflowLines = false;
            };
            "Terminal Features".BlinkingCursorEnabled = true;
          };
        }
      ];
      home.file.".local/share/konsole/Breeze.colorscheme".text = builtins.replaceStrings
        [ "Opacity=1" ] [ "Opacity=0.9\nBlur=true" ]
        (builtins.readFile "${inputs.pkgs.konsole}/share/konsole/Breeze.colorscheme");
    };
    environment.persistence =
      let impermanence = inputs.config.nixos.system.impermanence;
      in inputs.lib.mkIf impermanence.enable
      {
        "${impermanence.root}".users.chn.directories = [ ".local/share/konsole" ".local/share/yakuake" ];
      };
  };
}
