inputs:
let bugs =
{
  # suspend & hibernate do not use platform
  suspend-hibernate-no-platform.systemd.sleep.extraConfig =
  ''
    SuspendState=freeze
    HibernateMode=shutdown
  '';
  # xmunet use old encryption
  xmunet.nixpkgs.config.packageOverrides = pkgs: { wpa_supplicant = pkgs.wpa_supplicant.overrideAttrs
    (attrs: { patches = attrs.patches ++ [ ./xmunet.patch ];}); };
  backlight.boot.kernelParams = [ "nvidia.NVreg_RegistryDwords=EnableBrightnessControl=1" ];
  amdpstate.boot.kernelParams = [ "amd_pstate=active" ];
  iwlwifi.boot.extraModprobeConfig =
    [ "options iwlwifi power_save=0" "options iwlmvm power_scheme=1" "options iwlwifi uapsd_disable=1" ];
};
in
{
  options.nixos.bugs = inputs.lib.mkOption
  {
    type = inputs.lib.types.listOf (inputs.lib.types.enum (builtins.attrNames bugs));
    default = [];
  };
  config = inputs.lib.mkMerge (builtins.map
    (bug: inputs.lib.mkIf (builtins.elem bug inputs.config.nixos.bugs) bugs.${bug})
    (builtins.attrNames bugs));
}
