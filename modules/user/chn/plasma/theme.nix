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
        kdeglobals.KDE.widgetStyle.value = "kvantum";
        "Kvantum/kvantum.kvconfig".General.theme.value = "Fluent-round";
        kwinrc =
        {
          Effect-blur.BlurStrength.value = 10;
          Effect-kwin4_effect_translucency.MoveResize.value = 75;
          Effect-wobblywindows =
            { AdvancedMode.value = true; Drag.value = 85; Stiffness.value = 10; WobblynessLevel.value = 1; };
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
}
