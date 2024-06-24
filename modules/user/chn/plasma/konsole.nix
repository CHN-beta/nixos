inputs:
{
  config = inputs.lib.mkIf (builtins.elem "desktop" inputs.config.nixos.packages._packageSets)
  {
    home-manager.users.chn.config =
    {
      programs.plasma =
      {
        overrideConfig = true;
        resetFiles = [ "konsolerc" "yakuakerc" ];
        configFile =
        {
          yakuakerc =
          {
            Appearance =
            {
              HideSkinBorders.value = true;
              Skin.value = "Slate";
              Translucency.value = true;
            };
            "Desktop Entry".DefaultProfile.value = "plasma-manager.profile";
            Dialogs.FirstRun.value = false;
            Window =
            {
              KeepOpen.value = false;
              KeepOpenAfterLastSessionCloses.value = true;
              ShowSystrayIcon.value = false;
            };
          };
          konsolerc =
          {
            "Desktop Entry".DefaultProfile.value = "plasma-manager.profile";
            "MainWindow.Toolbar sessionToolbar".ToolButtonStyle.value = "IconOnly";
          };
        };
        dataFile."konsole/plasma-manager.profile" =
        {
          Appearance =
          {
            AntiAliasFonts.value = true;
            BoldIntense.value = true;
            ColorScheme.value = "Breeze";
            Font.value = "FiraCode Nerd Font Mono,10,-1,5,50,0,0,0,0,0";
            UseFontLineChararacters.value = true;
            WordModeAttr.value = false;
          };
          "Cursor Options".CursorShape.value = 1;
          General =
          {
            Name.value = "plasma-manager";
            Parent.value = "FALLBACK/";
            TerminalCenter.value = true;
            TerminalMargin.value = 1;
          };
          "Interaction Options" =
          {
            AutoCopySelectedText.value = true;
            TrimLeadingSpacesInSelectedText.value = true;
            TrimTrailingSpacesInSelectedText.value = true;
            UnderlineFilesEnabled.value = true;
          };
          Scrolling = { HistoryMode.value = 2; ReflowLines.value = false; };
          "Terminal Features".BlinkingCursorEnabled.value = true;
        };
      };
      home.file.".local/share/konsole/Breeze.colorscheme".text = builtins.replaceStrings
        [ "Opacity=1" ] [ "Opacity=0.9\nBlur=true" ]
        (builtins.readFile "${inputs.pkgs.konsole}/share/konsole/Breeze.colorscheme");
    };
    environment.persistence =
      let impermanence = inputs.config.nixos.system.impermanence;
      in inputs.lib.mkIf impermanence.enable (inputs.lib.mkMerge (builtins.map
        (user:
          { "${impermanence.root}".users.${user}.directories = [ ".local/share/konsole" ".local/share/yakuake" ]; })
        inputs.config.nixos.user.users));
  };
}
