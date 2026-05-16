inputs:
{
  options.nixos.services.rsshub = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule { options =
    {
      hostname = mkOption { type = types.str; default = "rsshub.chn.moe"; };
    };});
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) rsshub; in inputs.lib.mkIf (rsshub != null)
  {
    virtualisation.oci-containers.containers.rsshub =
    {
      image = "rsshub:latest";
      imageFile = inputs.self.src.rsshub;
      ports = [ "127.0.0.1:5221:5221/tcp" ];
      environmentFiles = [ inputs.config.nixos.system.sops.templates."rsshub/env".path ];
    };
    nixos =
    {
      system.sops =
      {
        templates."rsshub/env".content = let inherit (inputs.config.nixos.system.sops) placeholder; in
        ''
          PORT=5221
          CACHE_TYPE=memory
          PIXIV_REFRESHTOKEN='${placeholder."rsshub/pixiv-refreshtoken"}'
          PIXIV_BYPASS_CDN=true
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
        secrets = (builtins.listToAttrs (builtins.map (secret: inputs.lib.nameValuePair "rsshub/${secret}" {})
        [
          "pixiv-refreshtoken"
          "youtube-key" "youtube-client-id" "youtube-client-secret" "youtube-refresh-token"
          "twitter-auth-token"
          "bilibili-cookie"
          "zhihu-cookies"
        ]));
      };
      services.nginx.https.${rsshub.hostname}.location."/".proxy.upstream = "http://127.0.0.1:5221";
    };
  };
}
