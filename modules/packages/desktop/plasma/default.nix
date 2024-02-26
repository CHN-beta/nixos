inputs:
{
  imports = inputs.localLib.mkModules [ ./konsole.nix ];
  config.nixos.users.sharedModules = inputs.lib.mkIf inputs.config.nixos.system.gui.enable
  [{
    config.programs.plasma = inputs.lib.mkMerge
    [
      # TODO: autostart, panel, discard user changed settings
      # general
      {
        enable = true;
        configFile.plasma-localerc = { Formats.LANG = "en_US.UTF-8"; Translations.LANGUAGE = "zh_CN"; };
      }
      # kwin
      {
        kwin.titlebarButtons =
        {
          right = [ "help" "keep-below-windows" "keep-above-windows" "minimize" "maximize" "close" ];
          left = [ "more-window-actions" ];
        };
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
    ];
  }];
}
