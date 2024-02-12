inputs:
{
  config = inputs.lib.mkIf inputs.config.nixos.system.gui.enable
  {
    home-manager.users.chn.config =
    {
      programs.plasma =
      {
        overrideConfig = true;
        overrideConfigFiles = [ "konsolerc" "yakuakerc" ];
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
      };
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
