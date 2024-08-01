inputs:
{
  config = inputs.lib.mkIf (builtins.elem "desktop" inputs.config.nixos.packages._packageSets)
  {
    nixos.user.sharedModules =
    [{
      config.programs.plasma = 
      {
        enable = true;
        configFile =
        {
          plasma-localerc = { Formats.LANG.value = "en_US.UTF-8"; Translations.LANGUAGE.value = "zh_CN"; };
          baloofilerc."Basic Settings".Indexing-Enabled.value = false;
        };
        powerdevil.autoSuspend.action = "nothing";
      };
    }];
  };
}
