inputs:
  let
    inherit (inputs.localLib) stripeTabs;
    inherit (builtins) map attrNames;
    inherit (inputs.lib) mkMerge mkIf mkOption types;
    bugs =
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
    };
  in
    {
      options.nixos.bugs = mkOption
      {
        type = types.listOf (types.enum (attrNames bugs));
        default = [];
      };
      config = mkMerge (map (bug: mkIf (builtins.elem bug inputs.config.nixos.bugs) bugs.${bug}) (attrNames bugs));
    }
