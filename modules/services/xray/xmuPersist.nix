inputs:
{
  options.nixos.services.xray.xmuPersist = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule (submoduleInputs: { options =
    {
      keepAliveHost = mkOption { type = types.nonEmptyStr; default = "blog.chn.moe"; };
    };}));
    default = null;
  };
  config = let inherit (inputs.config.nixos.services.xray) xmuPersist; in inputs.lib.mkIf (xmuPersist != null)
  {
    nixos.system.sops =
    {
      templates."xray-xmu-persist-cookie.txt" =
      {
        owner = inputs.config.users.users.v2ray.name;
        group = inputs.config.users.users.v2ray.group;
        content = let cookie = inputs.config.nixos.system.sops.placeholder."xray-xmu-client/cookie"; in
        ''
          .webvpn.xmu.edu.cn	TRUE	/	TRUE	0	wengine_vpn_ticketwebvpn_xmu_edu_cn	${cookie}
          webvpn.xmu.edu.cn	FALSE	/	TRUE	0	show_vpn	0
          webvpn.xmu.edu.cn	FALSE	/	TRUE	0	heartbeat	1
          webvpn.xmu.edu.cn	FALSE	/	TRUE	0	show_faq	0
          webvpn.xmu.edu.cn	FALSE	/	FALSE	0	refresh	0
        '';
      };
      secrets."xray-xmu-client/cookie" = {};
    };
    systemd =
    {
      services.xray-xmu-persist =
      {
        script =
          let
            curl = "${inputs.pkgs.curl}/bin/curl";
            cookie = inputs.config.nixos.system.sops.templates."xray-xmu-persist-cookie.txt".path;
          in
          ''
            ${curl} -s -o /dev/null -w "%{http_code}\n" -b ${cookie} \
              "https://webvpn.xmu.edu.cn${inputs.pkgs.localPackages.webvpnPath xmuPersist.keepAliveHost}/";
          '';
        serviceConfig = { Type = "oneshot"; User = "v2ray"; Group = "v2ray"; };
      };
      timers.xray-xmu-persist =
      {
        wantedBy = [ "timers.target" ];
        timerConfig = { OnCalendar = "*-*-* *:*:00"; Unit = "xray-xmu-persist.service"; };
      };
    };
    users =
    {
      users.v2ray = { uid = inputs.config.nixos.user.uid.v2ray; group = "v2ray"; isSystemUser = true; };
      groups.v2ray.gid = inputs.config.nixos.user.gid.v2ray;
    };
  };
}
