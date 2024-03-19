inputs:
{
  config = inputs.lib.mkIf inputs.config.nixos.system.gui.enable
  {
    home-manager.users.chn.config.programs.plasma =
    {
      workspace =
      {
        theme = "Fluent-round-light";
        colorScheme = "FluentLight";
        cursorTheme = "Breeze_Snow";
        lookAndFeel = "com.github.vinceliuice.Fluent-round-light";
        iconTheme = "Tela-circle";
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
    };
  };
}
