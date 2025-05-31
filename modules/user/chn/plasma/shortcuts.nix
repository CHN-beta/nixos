inputs:
{
  config = inputs.lib.mkIf (inputs.config.nixos.model.type == "desktop")
  {
    home-manager.users.chn.config.programs.plasma =
    {
      overrideConfig = true;
      resetFiles = [ "kglobalshortcutsrc" "khotkeysrc" ];
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
            ExposeAll = "Meta+Tab";
            "Show Desktop" = "Meta+D";
            "Suspend Compositing" = "Alt+Shift+F12";
            "Walk Through Windows" = "Alt+Tab";
            "Walk Through Windows (Reverse)" = "Alt+Shift+Backtab";
            "Window Above Other Windows" = "Meta+Shift+Up";
            "Window Below Other Windows" = "Meta+Shift+Down";
            "Window Close" = "Alt+F4";
            "Window Maximize" = "Meta+Ctrl+Up";
            "Window Minimize" = "Meta+Ctrl+Down";
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
            "Switch to Previous Desktop" = [ "Ctrl+PgUp" "Ctrl+Num+PgUp" ];
            "Switch to Next Desktop" = [ "Ctrl+PgDown" "Ctrl+Num+PgDown" ];
            "Window to Previous Desktop" = [ "Meta+Ctrl+PgUp" "Meta+Ctrl+Num+PgUp" ];
            "Window to Next Desktop" = [ "Meta+Ctrl+PgDown" "Meta+Ctrl+Num+PgDown" ];
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
        # virt-manager
        { "virt-manager.desktop"._launch = "Meta+V"; }
        # system monitor
        { "org.kde.plasma-systemmonitor.desktop"._launch = "Meta+Esc"; }
      ];
    };
  };
}
