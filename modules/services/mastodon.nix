inputs:
{
  options.nixos.services.mastodon = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    hostname = mkOption { type = types.str; default = "dudu.chn.moe"; };
  };
  config =
    let
      inherit (inputs.config.nixos.services) mastodon;
      inherit (inputs.lib) mkIf;
      inherit (builtins) toString;
    in mkIf mastodon.enable
    {
      # TODO: remove in next release
      nixpkgs.overlays = [(final: prev: { mastodon = prev.mastodon.override
      {
        version = "4.2.5";
        patches = prev.patches or [] ++ [(final.fetchpatch
        {
          url = "https://github.com/mastodon/mastodon/compare/v4.2.4...v4.2.5.patch";
          hash = "sha256-CtzYV1i34s33lV/1jeNcr9p/x4Es1zRaf4l1sNWVKYk=";
        })];
      };})];
      services.mastodon =
      {
        enable = true;
        streamingProcesses = 1;
        enableUnixSocket = false;
        localDomain = mastodon.hostname;
        database =
        {
          createLocally = false;
          host = "127.0.0.1";
          passwordFile = inputs.config.sops.secrets."mastodon/postgresql".path;
        };
        redis.createLocally = false;
        smtp =
        {
          createLocally = false;
          user = "bot@chn.moe";
          port = 465;
          passwordFile = inputs.config.sops.secrets."mastodon/mail".path;
          host = "mail.chn.moe";
          fromAddress = "bot@chn.moe";
          authenticate = true;
        };
        extraEnvFiles = [ inputs.config.sops.templates."mastodon/env".path ];
      };
      nixos.services =
      {
        postgresql = { enable = true; instances.mastodon = {}; };
        redis.instances.mastodon.port = inputs.config.services.mastodon.redis.port;
        nginx =
        {
          enable = true;
          https."${mastodon.hostname}".location =
          {
            "/system/".alias.path = "/var/lib/mastodon/public-system/";
            "/".static =
              { root = "${inputs.config.services.mastodon.package}/public"; tryFiles = [ "$uri" "@proxy" ]; };
            "@proxy".proxy =
              { upstream = "http://127.0.0.1:${toString inputs.config.services.mastodon.webPort}"; websocket = true; };
            "/api/v1/streaming/".proxy =
            {
              upstream = "http://unix:/run/mastodon-streaming/streaming-1.socket";
              websocket = true;
            };
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
        templates."mastodon/env" =
        {
          owner = "mastodon";
          content =
          ''
            REDIS_PASSWORD=${inputs.config.sops.placeholder."redis/mastodon"}
            SMTP_SSL=true
            SMTP_AUTH_METHOD=plain
          '';
        };
      };
      environment.systemPackages = [ inputs.config.services.mastodon.package ];
      # sudo -u mastodon mastodon-tootctl accounts modify chn --role Owner
    };
}
