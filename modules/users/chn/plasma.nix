{
  # plasma-manager is not mature, so only use 
  config.home-manager.users.chn.config.programs.plasma =
  {
    enable = true;
    shortcuts =
    {
      # crow translate
      "io.crow_translate.CrowTranslate.desktop"."TranslateSelectedText" = "Ctrl+Alt+E";

      # display
      "kded5"."display" = [ "Display" "Meta+P" ];
      "kwin"."view_actual_size" = "Meta+0";
      "kwin"."view_zoom_in" = ["Meta++" "Meta+="];
      "kwin"."view_zoom_out" = "Meta+-";
      "org_kde_powerdevil"."Decrease Screen Brightness" = "Monitor Brightness Down";
      "org_kde_powerdevil"."Increase Screen Brightness" = "Monitor Brightness Up";

      # volume
      "kmix" =
      {
        "decrease_volume" = "Volume Down";
        "increase_volume" = "Volume Up";
        "mic_mute" = [ "Meta+Volume Mute" ];
        "mute" = "Volume Mute";
      };

      # session
      "ksmserver"."Lock Session" = [ "Meta+L" "Screensaver" ];
      "ksmserver"."Log Out" = "Ctrl+Alt+Del";
      "org_kde_powerdevil"."Turn Off Screen" = "Meta+Ctrl+L";

      # mouse
      "kwin"."MoveMouseToCenter" = "Meta+F6";

      # window
      "kwin"."Overview" = "Meta+Tab";
      "kwin"."Show Desktop" = "Meta+D";
      "kwin"."Suspend Compositing" = "Alt+Shift+F12";
      "kwin"."Walk Through Windows" = "Alt+Tab";
      "kwin"."Walk Through Windows (Reverse)" = "Alt+Shift+Backtab";
      "kwin"."Window Above Other Windows" = "Meta+Shift+PgUp";
      "kwin"."Window Below Other Windows" = "Meta+Shift+PgDown";
      "kwin"."Window Close" = "Alt+F4";
      "kwin"."Window Maximize" = "Meta+PgUp";
      "kwin"."Window Minimize" = "Meta+PgDown";
      "kwin"."Window Operations Menu" = "Alt+F3";
      "kwin"."Window Quick Tile Bottom" = "Meta+Down";
      "kwin"."Window Quick Tile Left" = "Meta+Left";
      "kwin"."Window Quick Tile Right" = "Meta+Right";
      "kwin"."Window Quick Tile Top" = "Meta+Up";

      # virtual desktop
      "kwin"."Switch One Desktop Down" = "Meta+Ctrl+Down";
      "kwin"."Switch One Desktop Up" = "Meta+Ctrl+Up";
      "kwin"."Switch One Desktop to the Left" = "Meta+Ctrl+Left";
      "kwin"."Switch One Desktop to the Right" = "Meta+Ctrl+Right";
      "kwin"."Window One Desktop Down" = "Meta+Ctrl+Shift+Down";
      "kwin"."Window One Desktop Up" = "Meta+Ctrl+Shift+Up";
      "kwin"."Window One Desktop to the Left" = "Meta+Ctrl+Shift+Left";
      "kwin"."Window One Desktop to the Right" = "Meta+Ctrl+Shift+Right";

      # media
      "mediacontrol"."nextmedia" = "Media Next";
      "mediacontrol"."pausemedia" = "Media Pause";
      "mediacontrol"."playpausemedia" = [ "Pause" "Media Play" ];
      "mediacontrol"."previousmedia" = "Media Previous";
      "mediacontrol"."stopmedia" = "Media Stop";

      # dolphin
      "org.kde.dolphin.desktop"."_launch" = "Meta+E";

      # konsole
      "org.kde.konsole.desktop"."_launch" = "Ctrl+Alt+T";

      # krunner
      "org.kde.krunner.desktop"."_launch" = "Alt+Space";

      # screenshot
      "org.kde.spectacle.desktop"."ActiveWindowScreenShot" = "Meta+Print";
      "org.kde.spectacle.desktop"."CurrentMonitorScreenShot" = [ ];
      "org.kde.spectacle.desktop"."FullScreenScreenShot" = "Shift+Print";
      "org.kde.spectacle.desktop"."OpenWithoutScreenshot" = [ ];
      "org.kde.spectacle.desktop"."RectangularRegionScreenShot" = "Meta+Shift+Print";
      "org.kde.spectacle.desktop"."WindowUnderCursorScreenShot" = "Meta+Ctrl+Print";
      "org.kde.spectacle.desktop"."_launch" = "Print";

      # settings
      "systemsettings.desktop"."_launch" = "Meta+I";

      # yakuake
      "yakuake"."toggle-window-state" = "Meta+Space";
    };
    configFile =
    {
      # baloo
      # "baloofilerc"."Basic Settings"."Indexing-Enabled" = false;

      # dolphin
      "dolphinrc"."General"."ShowFullPath" = true;
      "dolphinrc"."PreviewSettings"."Plugins" = "blenderthumbnail,comicbookthumbnail,djvuthumbnail,ebookthumbnail,exrthumbnail,marble_thumbnail_geojson,marble_thumbnail_gpx,jpegthumbnail,marble_thumbnail_kmz,marble_thumbnail_kml,kraorathumbnail,windowsimagethumbnail,windowsexethumbnail,mltpreview,mobithumbnail,opendocumentthumbnail,marble_thumbnail_osm,palathumbcreator,gsthumbnail,rawthumbnail,svgthumbnail,imagethumbnail,fontthumbnail,directorythumbnail,textthumbnail,webarchivethumbnail,ffmpegthumbs,audiothumbnail";

      "kcminputrc"."Mouse"."cursorTheme" = "breeze_cursors";
      "kdeglobals"."KDE"."widgetStyle" = "kvantum";
      "kdeglobals"."KFileDialog Settings"."Allow Expansion" = true;
      "kdeglobals"."KFileDialog Settings"."Automatically select filename extension" = true;
      "kdeglobals"."KFileDialog Settings"."Show Bookmarks" = true;
      "kdeglobals"."KFileDialog Settings"."Show Full Path" = true;
      "kdeglobals"."KFileDialog Settings"."Show Inline Previews" = true;
      "kdeglobals"."KFileDialog Settings"."Show Preview" = true;
      "kdeglobals"."KFileDialog Settings"."Show Speedbar" = true;
      "kdeglobals"."KFileDialog Settings"."Show hidden files" = true;
      "kdeglobals"."KFileDialog Settings"."Sort by" = "Name";
      "kdeglobals"."KFileDialog Settings"."Sort directories first" = true;
      "kdeglobals"."KFileDialog Settings"."Sort hidden files last" = true;
      "kdeglobals"."KFileDialog Settings"."View Style" = "DetailTree";

      "krunnerrc"."General"."FreeFloating" = true;
      "krunnerrc"."Plugins"."baloosearchEnabled" = false;
      "kscreenlockerrc"."Daemon"."Autolock" = false;

      # https://www.fanbox.cc/@peas0125/posts/5405326
      "kscreenlockerrc"."Greeter.Wallpaper.org.kde.image.General"."Image" = ./wallpaper/fanbox-5405326-x4-chop.png;
      "kscreenlockerrc"."Greeter.Wallpaper.org.kde.image.General"."PreviewImage" =
        ./wallpaper/fanbox-5405326-x4-chop.png;


      "kwinrc"."Effect-blur"."BlurStrength" = 10;
      "kwinrc"."Effect-kwin4_effect_translucency"."MoveResize" = 75;
      "kwinrc"."Effect-wobblywindows"."AdvancedMode" = true;
      "kwinrc"."Effect-wobblywindows"."Drag" = 85;
      "kwinrc"."Effect-wobblywindows"."Stiffness" = 10;
      "kwinrc"."Effect-wobblywindows"."WobblynessLevel" = 1;
      "kwinrc"."Plugins"."blurEnabled" = true;
      "kwinrc"."Plugins"."contrastEnabled" = false;
      "kwinrc"."Plugins"."kwin4_effect_dimscreenEnabled" = true;
      "kwinrc"."Plugins"."kwin4_effect_translucencyEnabled" = true;
      "kwinrc"."Plugins"."padding" = 4;
      "kwinrc"."Plugins"."wobblywindowsEnabled" = true;
      "kwinrc"."SubSession: 3435a388-a8b3-4d1d-9794-b8c30162ce16"."active" = "-1";
      "kwinrc"."SubSession: 3435a388-a8b3-4d1d-9794-b8c30162ce16"."count" = 0;
      "kwinrc"."SubSession: 6a473a77-85df-4e49-8c74-bdb06d1f0efd"."active" = "-1";
      "kwinrc"."SubSession: 6a473a77-85df-4e49-8c74-bdb06d1f0efd"."count" = 0;
      "kwinrc"."Tiling"."padding" = 4;
      "kwinrc"."Wayland"."InputMethod[$e]" = "/run/current-system/sw/share/applications/org.fcitx.Fcitx5.desktop";
      "kwinrc"."Windows"."RollOverDesktops" = true;
      "kwinrc"."Xwayland"."Scale" = 1;
      "kwinrc"."Xwayland"."XwaylandEavesdrops" = "Combinations";
      "kwinrc"."org.kde.kdecoration2"."ButtonsOnLeft" = "M";
      "kwinrc"."org.kde.kdecoration2"."ButtonsOnRight" = "BFIAX";
      "kwinrulesrc"."06734e18-08f2-47f9-a6dc-9085d95fe9b0"."Description" = "org.kde.kruler 的设置";
      "kwinrulesrc"."06734e18-08f2-47f9-a6dc-9085d95fe9b0"."above" = true;
      "kwinrulesrc"."06734e18-08f2-47f9-a6dc-9085d95fe9b0"."aboverule" = 2;
      "kwinrulesrc"."06734e18-08f2-47f9-a6dc-9085d95fe9b0"."skipswitcher" = true;
      "kwinrulesrc"."06734e18-08f2-47f9-a6dc-9085d95fe9b0"."skipswitcherrule" = 2;
      "kwinrulesrc"."06734e18-08f2-47f9-a6dc-9085d95fe9b0"."wmclass" = "org.kde.kruler";
      "kwinrulesrc"."06734e18-08f2-47f9-a6dc-9085d95fe9b0"."wmclassmatch" = 1;
      "kwinrulesrc"."1"."Description" = "element 的设置";
      "kwinrulesrc"."1"."activity" = "00000000-0000-0000-0000-000000000000";
      "kwinrulesrc"."1"."activityrule" = 2;
      "kwinrulesrc"."1"."wmclass" = "element";
      "kwinrulesrc"."1"."wmclassmatch" = 1;
      "kwinrulesrc"."2"."Description" = "org.telegram.desktop 的设置";
      "kwinrulesrc"."2"."activity" = "00000000-0000-0000-0000-000000000000";
      "kwinrulesrc"."2"."activityrule" = 2;
      "kwinrulesrc"."2"."wmclass" = "org.telegram.desktop";
      "kwinrulesrc"."2"."wmclassmatch" = 1;
      "kwinrulesrc"."3"."Description" = "org.kde.kruler 的设置";
      "kwinrulesrc"."3"."above" = true;
      "kwinrulesrc"."3"."aboverule" = 2;
      "kwinrulesrc"."3"."skipswitcher" = true;
      "kwinrulesrc"."3"."skipswitcherrule" = 2;
      "kwinrulesrc"."3"."wmclass" = "org.kde.kruler";
      "kwinrulesrc"."3"."wmclassmatch" = 1;
      "kwinrulesrc"."8c1ccf0b-abf4-4d24-a848-522a76a2440d"."Description" = "element 的设置";
      "kwinrulesrc"."8c1ccf0b-abf4-4d24-a848-522a76a2440d"."activity" = "00000000-0000-0000-0000-000000000000";
      "kwinrulesrc"."8c1ccf0b-abf4-4d24-a848-522a76a2440d"."activityrule" = 2;
      "kwinrulesrc"."8c1ccf0b-abf4-4d24-a848-522a76a2440d"."wmclass" = "element";
      "kwinrulesrc"."8c1ccf0b-abf4-4d24-a848-522a76a2440d"."wmclassmatch" = 1;
      "kwinrulesrc"."General"."count" = 3;
      "kwinrulesrc"."General"."rules" = "1,2,3";
      "kwinrulesrc"."e75e010c-c094-4e6c-a98e-fe011e563466"."Description" = "org.telegram.desktop 的设置";
      "kwinrulesrc"."e75e010c-c094-4e6c-a98e-fe011e563466"."activity" = "00000000-0000-0000-0000-000000000000";
      "kwinrulesrc"."e75e010c-c094-4e6c-a98e-fe011e563466"."activityrule" = 2;
      "kwinrulesrc"."e75e010c-c094-4e6c-a98e-fe011e563466"."wmclass" = "org.telegram.desktop";
      "kwinrulesrc"."e75e010c-c094-4e6c-a98e-fe011e563466"."wmclassmatch" = 1;
      "kxkbrc"."Layout"."DisplayNames" = "";
      "kxkbrc"."Layout"."LayoutList" = "us";
      "kxkbrc"."Layout"."Use" = true;
      "kxkbrc"."Layout"."VariantList" = "";
      "plasma-localerc"."Formats"."LANG" = "en_US.UTF-8";
      "plasma-localerc"."Translations"."LANGUAGE" = "zh_CN";
      "plasmanotifyrc"."Notifications"."PopupPosition" = "BottomRight";
      "plasmarc"."Wallpapers"."usersWallpapers" = "/home/chn/Desktop/.桌面/twin_96734339_x2.png,/home/chn/Desktop/.桌面/E_yCTfDUUAgykjX_x8.jpeg,/home/chn/Desktop/.桌面/102692178_p0_[L1][x2.00].png,/home/chn/Desktop/.桌面/111392869_p0.png,/home/chn/Desktop/.桌面/HlszomyrfyxKLtpkVixEtikq_x4_chop.png";
    };
  };
}
