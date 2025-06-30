inputs:
{
  options.nixos.services.xray.xmuClient = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule (submoduleInputs: { options =
    {
      hostname = mkOption { type = types.nonEmptyStr; default = "xserverxmu.chn.moe"; };
    };}));
    default = null;
  };
  config = let inherit (inputs.config.nixos.services.xray) xmuClient; in inputs.lib.mkIf (xmuClient != null)
  {
    sops =
    {
      templates."xray-xmu-client.json" =
      {
        owner = inputs.config.users.users.v2ray.name;
        group = inputs.config.users.users.v2ray.group;
        content = builtins.toJSON
        {
          log.loglevel = "warning";
          inbounds =
          [
            {
              port = 10983;
              protocol = "dokodemo-door";
              settings = { network = "tcp,udp"; followRedirect = true; };
              streamSettings.sockopt.tproxy = "tproxy";
              tag = "tproxy-in";
            }
            { port = 10984; protocol = "socks"; settings.udp = true; tag = "socks-in"; }
          ];
          outbounds =
          [{
            protocol = "vless";
            settings.vnext =
            [{
              address = xmuClient.hostname;
              port = 443;
              users = [{ id = inputs.config.sops.placeholder."xray-xmu-client/uuid"; encryption = "none"; }];
            }];
            streamSettings =
            {
              network = "xhttp";
              security = "tls";
              xhttpSettings =
              {
                path =
                  let
                    inherit (xmuClient) hostname;
                    paddedLength = ((builtins.div ((builtins.stringLength hostname) - 1) 16) + 1) * 16;
                    paddedString = builtins.concatStringsSep ""
                      (builtins.genList
                        (n: if n < builtins.stringLength hostname then builtins.substring n 1 hostname else "0")
                        paddedLength);
                    paddedHex = inputs.pkgs.localPackages.aes128CfbHex
                      { data = hostname; key = "wrdvpnisthebest!"; iv = "wrdvpnisthebest!"; };
                    prefix = builtins.concatStringsSep "" (builtins.map
                      (c: inputs.lib.toHexString (inputs.lib.charToInt c))
                      (inputs.lib.stringToCharacters "wrdvpnisthebest!"));
                  in "/https/${prefix}${paddedHex}/xsession";
                mode = "stream-one";
                security = "tls";
                extra.headers.Cookie = "show_vpn=0; heartbeat=1; show_faq=0; "
                  + "wengine_vpn_ticketwebvpn_xmu_edu_cn=${inputs.config.sops.placeholder."xray-xmu-client/cookie"}";
              };
            };
          }];
        };
      };
      secrets = { "xray-xmu-client/uuid" = {}; "xray-xmu-client/cookie" = {}; };
    };
    systemd.services =
    {
      xray-xmu-client =
      {
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        script =
          "exec ${inputs.pkgs.xray}/bin/xray -config ${inputs.config.sops.templates."xray-xmu-client.json".path}";
        serviceConfig =
        {
          User = "v2ray";
          Group = "v2ray";
          CapabilityBoundingSet = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
          AmbientCapabilities = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
          NoNewPrivileges = true;
          LimitNPROC = 65536;
          LimitNOFILE = 524288;
          CPUSchedulingPolicy = "rr";
        };
        restartTriggers = [ inputs.config.sops.templates."xray-xmu-client.json".file ];
      };
    };
    users =
    {
      users.v2ray = { uid = inputs.config.nixos.user.uid.v2ray; group = "v2ray"; isSystemUser = true; };
      groups.v2ray.gid = inputs.config.nixos.user.gid.v2ray;
    };
  };
}
