inputs:
{
  config = inputs.lib.mkIf inputs.config.nixos.system.gui.enable
  {
    home-manager.users.chn.config =
    {
      programs.plasma =
      {
        workspace =
        {
          theme = "breeze-light";
          colorScheme = "BreezeLight";
          cursor.theme = "breeze_cursors";
          lookAndFeel = "org.kde.klassylighttraditional.desktop";
          # ~/.config/kdeglobals [Icons]
          iconTheme = "klassy";
        };
        configFile =
        {
          kwinrc =
          {
            Effect-blur.BlurStrength.value = 10;
            Effect-kwin4_effect_translucency.MoveResize.value = 75;
            Effect-wobblywindows =
            {
              AdvancedMode.value = true;
              Drag.value = 85;
              Stiffness.value = 10;
              WobblynessLevel.value = 1;
              ResizeWobble.value = false;
            };
            Plugins =
            {
              blurEnabled.value = true;
              kwin4_effect_dimscreenEnabled.value = true;
              kwin4_effect_translucencyEnabled.value = true;
              padding.value = 4;
              wobblywindowsEnabled.value = true;
            };
          };
        };
      };
    };
  };
}
