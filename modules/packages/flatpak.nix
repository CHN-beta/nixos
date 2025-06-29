inputs:
{
  options.nixos.packages.flatpak = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = if builtins.elem inputs.config.nixos.model.type [ "desktop" "server" ] then {} else null;
  };
  config = let inherit (inputs.config.nixos.packages) flatpak; in inputs.lib.mkIf (flatpak != null)
  {
    services.flatpak = { enable = true; uninstallUnmanaged = true; };
  };
}
