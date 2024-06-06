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
      suspend-hibernate-waydroid.systemd.services =
        let
          systemctl = "${inputs.pkgs.systemd}/bin/systemctl";
        in
        {
          "waydroid-hibernate" =
          {
            description = "waydroid hibernate";
            wantedBy = [ "systemd-hibernate.service" "systemd-suspend.service" ];
            before = [ "systemd-hibernate.service" "systemd-suspend.service" ];
            serviceConfig.Type = "oneshot";
            script = "${systemctl} stop waydroid-container";
          };
          "waydroid-resume" =
          {
            description = "waydroid resume";
            wantedBy = [ "systemd-hibernate.service" "systemd-suspend.service" ];
            after = [ "systemd-hibernate.service" "systemd-suspend.service" ];
            serviceConfig.Type = "oneshot";
            script = "${systemctl} start waydroid-container";
          };
        };
      backlight.boot.kernelParams = [ "nvidia.NVreg_RegistryDwords=EnableBrightnessControl=1" ];
      amdpstate.boot.kernelParams = [ "amd_pstate=active" ];
      hibernate-mt7921e.powerManagement.resumeCommands =
        let modprobe = "${inputs.pkgs.kmod}/bin/modprobe"; in "${modprobe} -r -w 3000 mt7921e && ${modprobe} mt7921e";
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
