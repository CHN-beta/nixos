inputs:
{
  imports = inputs.localLib.findModules ./.;
  config = inputs.lib.mkIf (inputs.config.nixos.packages.desktop != null)
  {
    home-manager.users.chn.config.programs.plasma = inputs.lib.mkMerge
    [
      # TODO: panel, discard user changed settings
      # kwin
      {
        kwin =
        {
          titlebarButtons =
          {
            right = [ "help" "keep-below-windows" "keep-above-windows" "minimize" "maximize" "close" ];
            left = [ "more-window-actions" ];
          };
          virtualDesktops = { rows = 1; number = 6; };
          effects = { shakeCursor.enable = true; desktopSwitching.animation = "slide"; };
        };
        windows.allowWindowsToRememberPositions = false;
        configFile =
        {
          plasmanotifyrc.Notifications.PopupPosition.value = "BottomRight";
          kwinrc =
          {
            Tiling.padding.value = 4;
            Wayland."InputMethod" =
            {
              value = "/run/current-system/sw/share/applications/org.fcitx.Fcitx5.desktop";
              shellExpand = true;
            };
            Windows.RollOverDesktops.value = true;
            Compositing = { AllowTearing.value = false; WindowsBlockCompositing.value = false; };
          };
        };
      }
      # dolphin and file chooser
      {
        configFile =
        {
          dolphinrc =
          {
            General = { ShowFullPath.value = true; FilterBar.value = true; RememberOpenedTabs.value = false; };
            PreviewSettings.Plugins.value = builtins.concatStringsSep ","
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
            "Allow Expansion".value = true;
            "Automatically select filename extension".value = true;
            "Show Bookmarks".value = true;
            "Show Full Path".value = true;
            "Show Inline Previews".value = true;
            "Show Preview".value = true;
            "Show Speedbar".value = true;
            "Show hidden files".value = true;
            "Sort by".value = "Name";
            "Sort directories first".value = true;
            "Sort hidden files last".value = true;
            "View Style".value = "DetailTree";
          };
        };
        workspace.clickItemTo = "open";
      }
      # krunner
      { configFile.krunnerrc = { General.FreeFloating.value = true; Plugins.baloosearchEnabled.value = false; }; }
      # lock screen
      { configFile.kscreenlockerrc.Daemon.Autolock.value = false; }
    ];
  };
}
