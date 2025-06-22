inputs:
{
  config = inputs.lib.mkIf (inputs.config.nixos.system.gui.implementation == "kde")
  {
    home-manager.users.chn.config.programs.plasma.configFile.kdeglobals.General.accentColorFromWallpaper.value = true;
  };
}
