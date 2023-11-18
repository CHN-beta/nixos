inputs:
{
  options.nixos.services.mastodon = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
  };
  config =
    let
      inherit (inputs.config.nixos.services) mastodon;
      inherit (inputs.lib) mkIf;
      inherit (builtins) map listToAttrs toString replaceStrings filter;
    in mkIf mastodon.enable
    {
      services.mastodon =
      {
        enable = true;
        enableUnixSocket = false;
        database =
        {
          createLocally = false;
          host = "127.0.0.1";
          passwordFile = inputs.sops.secrets."mastodon/postgresql".path;
        };
        redis.createLocally = false;
        smtp =
        {
          createLocally = false;
          user = "bot@chn.moe";
          port = 465;
          passwordFile = inputs.sops.secrets."mastodon/mail".path;
          host = "mail.chn.moe";
          fromAddress = "bot@chn.moe";
          authenticate = true;
        };
        extraEnvFiles = [ inputs.sops.templates."mastodon/redis".path ];
      };
      nixos =
      {
        postgresql = { enable = true; instances.mastodon = {}; };
        redis.instances.mastodon.port = inputs.config.services.mastodon.redis.port;
        nginx =
        {
          enable = true;
          https.location =
          {
            "/".static =
              { root = "${inputs.config.services.mastodon.package}/public"; tryFiles = [ "$uri" "@proxy" ]; };
            "@proxy".proxy.upstream = "http://127.0.0.1:${toString inputs.config.services.mastodon.port}";
            "/system".static = 
          };
        };
      };
      sops =
      {
        secrets =
        {
          "mastodon/mail" = { owner = "mastodon"; key = "mail/bot"; };
          "mastodon/postgresql" = { owner = "mastodon"; key = "postgresql/mastodon"; };
        };
        templates."mastodon/redis.env" =
          { owner = "mastodon"; content = "REDIS_PASSWORD=${inputs.sops.placeholders."redis/mastodon"}"; };
      };
    };
}
