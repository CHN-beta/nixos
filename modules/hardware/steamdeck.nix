inputs:
{
  options.nixos.hardware.steamdeck = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.hardware) steamdeck; in inputs.lib.mkIf (steamdeck != null)
  {
    jovian =
    {
      steam = { enable = true; autoStart = true; user = "chn"; desktopSession = "plasma"; };
      steamos.useSteamOSConfig = true;
      decky-loader = { enable = true; package = inputs.pkgs.decky-loader-prerelease; };
      devices.steamdeck.enable = true;
      overlay.enable = true;
    };
    services.displayManager.sddm.enable = false;
    systemd.services.display-manager.enable = false;
    boot.initrd.kernelModules =
    [
      "hid_generic" "hid_multitouch" "i2c_designware_core" "i2c_designware_platform" "i2c_hid_acpi" "evdev"
      "i2c_hid_api"
    ];
    nixos.packages.packages._packages = [ inputs.pkgs.steamdeck-firmware ];
  };
}
