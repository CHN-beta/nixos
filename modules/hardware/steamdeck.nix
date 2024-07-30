inputs:
{
  options.nixos.hardware.steamdeck = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.hardware) steamdeck; in inputs.lib.mkIf (steamdeck != null)
  {
    jovian =
    {
      steam = { enable = true; autoStart = true; desktopSession = "plasma"; };
      steamos.useSteamOSConfig = true;
      decky-loader.enable = true;
      devices.steamdeck.enable = true;
      overlay.enable = true;
    };
  };
}
