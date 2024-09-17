inputs:
{
  options.nixos.services.waydroid = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.services) waydroid; in inputs.lib.mkIf (waydroid != null)
    { virtualisation.waydroid.enable = true; };
}

# sudo waydroid shell wm set-fix-to-user-rotation enabled
# /var/lib/waydroid/waydroid_base.prop
# default:
# ro.hardware.gralloc=gbm
# ro.hardware.egl=mesa
# nvidia:
# ro.hardware.gralloc=default
# ro.hardware.egl=swiftshader
