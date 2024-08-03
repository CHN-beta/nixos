inputs:
{
  options.nixos.packages.flatpak = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = if inputs.config.nixos.system.gui.enable then {} else null;
  };
  config = let inherit (inputs.config.nixos.packages) flatpak; in inputs.lib.mkIf (flatpak != null)
  {
    services.flatpak = { enable = true; uninstallUnmanaged = true; };
  };
}
