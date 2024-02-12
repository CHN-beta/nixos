inputs:
{
  config = inputs.lib.mkIf inputs.config.nixos.system.gui.enable
  {
    home-manager.users.chn.config.programs.plasma =
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
    };
  };
}
