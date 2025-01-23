inputs:
{
  options.nixos.services.rsshub = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule { options =
    {
      hostname = mkOption { type = types.nonEmptyStr; default = "rsshub.chn.moe"; };
    };});
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) rsshub; in inputs.lib.mkIf (rsshub != null)
  {
    systemd =
    {
      services.rsshub =
      {
        description = "rsshub";
        after = [ "network.target" "redis-rsshub.service" ];
        requires = [ "redis-rsshub.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig =
        {
          User = "rsshub";
          Group = "rsshub";
          EnvironmentFile = inputs.config.sops.templates."rsshub/env".path;
          WorkingDirectory = "${inputs.pkgs.localPackages.rsshub}";
          ExecStart = "${inputs.pkgs.localPackages.rsshub}/bin/rsshub";
          CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
          AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
        };
        restartTriggers = [ inputs.config.sops.templates."rsshub/env".content ];
      };
      tmpfiles.rules = [ "d /var/cache/rsshub 0700 rsshub rsshub" ];
    };
    sops =
    {
      templates."rsshub/env".content = let placeholder = inputs.config.sops.placeholder; in
      ''
        PORT=5221
        CACHE_TYPE=redis
        REDIS_URL='redis://:${placeholder."redis/rsshub"}@127.0.0.1:7116'
        PIXIV_REFRESHTOKEN='${placeholder."rsshub/pixiv-refreshtoken"}'
        YOUTUBE_KEY='${placeholder."rsshub/youtube-key"}'
        YOUTUBE_CLIENT_ID='${placeholder."rsshub/youtube-client-id"}'
        YOUTUBE_CLIENT_SECRET='${placeholder."rsshub/youtube-client-secret"}'
        YOUTUBE_REFRESH_TOKEN='${placeholder."rsshub/youtube-refresh-token"}'
        TWITTER_AUTH_TOKEN='${placeholder."rsshub/twitter-auth-token"}'
        ZHIHU_COOKIES='${placeholder."rsshub/zhihu-cookies"}'
        XDG_CONFIG_HOME='/var/cache/rsshub/chromium'
        XDG_CACHE_HOME='/var/cache/rsshub/chromium'
        BILIBILI_COOKIE_data0='${placeholder."rsshub/bilibili-cookie"}'
      '';
      secrets = (builtins.listToAttrs (builtins.map (secret: { name = "rsshub/${secret}"; value = {}; })
      [
        "pixiv-refreshtoken"
        "youtube-key" "youtube-client-id" "youtube-client-secret" "youtube-refresh-token"
        "twitter-auth-token"
        "bilibili-cookie"
        "zhihu-cookies"
      ]));
    };
    users =
    {
      users.rsshub = { uid = inputs.config.nixos.user.uid.rsshub; group = "rsshub"; isSystemUser = true; };
      groups.rsshub.gid = inputs.config.nixos.user.gid.rsshub;
    };
    nixos.services =
    {
      redis.instances.rsshub.port = 7116;
      nginx = { enable = true; https.${rsshub.hostname}.location."/".proxy.upstream = "http://127.0.0.1:5221"; };
    };
  };
}
