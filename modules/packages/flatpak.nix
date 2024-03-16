inputs:
{
  config = inputs.lib.mkIf (builtins.elem "desktop" inputs.config.nixos.packages._packageSets)
  {
    services.flatpak =
    {
      enable = true;
      uninstallUnmanagedPackages = true;
    };
  };
}
