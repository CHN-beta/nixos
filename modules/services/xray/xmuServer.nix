inputs:
{
  options.nixos.services.xray.xmuServer = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule { options =
    {
      hostname = mkOption { type = types.nonEmptyStr; default = "xserverxmu.chn.moe"; };
    };});
    default = null;
  };
  config = let inherit (inputs.config.nixos.services.xray) xmuServer; in inputs.lib.mkIf (xmuServer != null)
  {
    sops =
    {
      templates."xray-xmu-server.json" =
      {
        owner = inputs.config.users.users.v2ray.name;
        group = inputs.config.users.users.v2ray.group;
        content = builtins.toJSON
        {
          log.loglevel = "warning";
          inbounds =
          [{
            port = 4727;
            listen = "127.0.0.1";
            protocol = "vless";
            settings = { clients = [{ id = inputs.config.sops.placeholder."xray-xmu-server"; }]; decryption = "none"; };
            streamSettings = { network = "xhttp"; xhttpSettings = { mode = "stream-one"; path = "/xsession"; }; };
            tag = "in";
          }];
          outbounds = [{ protocol = "freedom"; tag = "freedom"; }];
        };
      };
      secrets."xray-xmu-server" = {};
    };
    systemd.services.xray-xmu-server =
    {
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      script =
        "exec ${inputs.pkgs.xray}/bin/xray -config ${inputs.config.sops.templates."xray-xmu-server.json".path}";
      serviceConfig =
      {
        User = "v2ray";
        Group = "v2ray";
        CapabilityBoundingSet = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
        AmbientCapabilities = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
        NoNewPrivileges = true;
        LimitNPROC = 65536;
        LimitNOFILE = 524288;
      };
      restartTriggers = [ inputs.config.sops.templates."xray-xmu-server.json".file ];
    };
    users =
    {
      users.v2ray = { uid = inputs.config.nixos.user.uid.v2ray; group = "v2ray"; isSystemUser = true; };
      groups.v2ray.gid = inputs.config.nixos.user.gid.v2ray;
    };
    nixos.services.nginx =
    {
      enable = true;
      https.${xmuServer.hostname}.location =
        { "/".return.return = "400"; "/xsession".proxy = { upstream = "127.0.0.1:4727"; grpc = true; }; };
    };
  };
}
