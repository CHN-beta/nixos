inputs:
{
  options.nixos.services = let inherit (inputs.lib) mkOption types; in
  {
    misskey =
    {
      enable = mkOption { type = types.bool; default = false; };
      autoStart = mkOption { type = types.bool; default = true; };
      port = mkOption { type = types.ints.unsigned; default = 9726; };
      hostname = mkOption { type = types.str; default = "misskey.chn.moe"; };
    };
    misskey-proxy = mkOption
    {
      type = types.attrsOf (types.submodule (submoduleInputs: { options =
      {
        hostname = mkOption { type = types.nonEmptyStr; default = submoduleInputs.config._module.args.name; };
        upstream = mkOption
        {
          type = types.oneOf [ types.nonEmptyStr (types.submodule { options =
          {
            address = mkOption { type = types.nonEmptyStr; default = "127.0.0.1"; };
            port = mkOption { type = types.ints.unsigned; default = 9726; };
          };})];
          default = "127.0.0.1:9726";
        };
      };}));
      default = {};
    };
  };
  config =
    let
      inherit (inputs.config.nixos.services) misskey misskey-proxy;
      inherit (inputs.localLib) stripeTabs attrsToList;
      inherit (inputs.lib) mkIf mkMerge;
      inherit (builtins) map listToAttrs toString replaceStrings;
    in mkMerge
    [
      (mkIf misskey.enable
      {
        systemd =
        {
          services.misskey =
          {
            description = "misskey";
            after = [ "network.target" "redis-misskey.service" "postgresql.service" "meilisearch-misskey.service" ];
            requires = [ "network.target" "redis-misskey.service" "postgresql.service" "meilisearch-misskey.service" ];
            wantedBy = [ "multi-user.target" ];
            environment.MISSKEY_CONFIG_YML = inputs.config.sops.templates."misskey/default.yml".path;
            serviceConfig = rec
            {
              User = inputs.config.users.users.misskey.name;
              Group = inputs.config.users.users.misskey.group;
              WorkingDirectory = "/var/lib/misskey/work";
              ExecStart = "${WorkingDirectory}/bin/misskey";
              CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
              AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
              Restart = "always";
              RuntimeMaxSec = "1d";
            };
          };
          tmpfiles.rules = [ "d /var/lib/misskey/files 0700 misskey misskey" ];
        };
        fileSystems =
        {
          "/var/lib/misskey/work" =
          {
            device = "${inputs.pkgs.localPackages.misskey}";
            options = [ "bind" "private" "x-gvfs-hide" ];
          };
          "/var/lib/misskey/work/files" =
          {
            device = "/var/lib/misskey/files";
            options = [ "bind" "private" "x-gvfs-hide" ];
          };
        };
        sops.templates."misskey/default.yml" =
        {
          content =
            let
              placeholder = inputs.config.sops.placeholder;
              misskey = inputs.config.nixos.services.misskey;
              redis = inputs.config.nixos.services.redis.instances.misskey;
            in
            ''
              url: https://${misskey.hostname}/
              port: ${toString misskey.port}
              db:
                host: 127.0.0.1
                port: 5432
                db: misskey
                user: misskey
                pass: ${placeholder."postgresql/misskey"}
                extra:
                  statement_timeout: 60000
              dbReplications: false
              redis:
                host: 127.0.0.1
                port: ${toString redis.port}
                pass: ${placeholder."redis/misskey"}
              meilisearch:
                host: 127.0.0.1
                port: 7700
                apiKey: ${placeholder."meilisearch/misskey"}
                ssl: false
                index: misskey
                scope: global
              id: 'aid'
              proxyBypassHosts:
                - api.deepl.com
                - api-free.deepl.com
                - www.recaptcha.net
                - hcaptcha.com
                - challenges.cloudflare.com
              proxyRemoteFiles: true
              signToActivityPubGet: true
              maxFileSize: 1073741824
            '';
          owner = inputs.config.users.users.misskey.name;
        };
        users =
        {
          users.misskey = { isSystemUser = true; group = "misskey"; home = "/var/lib/misskey"; createHome = true; };
          groups.misskey = {};
        };
        nixos.services =
        {
          redis.instances.misskey.port = 3545;
          postgresql = { enable = true; instances.misskey = {}; };
          meilisearch.instances.misskey = { user = inputs.config.users.users.misskey.name; port = 7700; };
        };
      })
      (mkIf (misskey-proxy != {})
      {
        nixos.services.nginx =
        {
          enable = true;
          httpProxy = listToAttrs (map
            (proxy: with proxy.value;
            {
              name = hostname;
              value =
              {
                rewriteHttps = true;
                locations."/" =
                {
                  upstream = if builtins.typeOf upstream == "string" then "http://${upstream}"
                    else "http://${upstream.address}:${toString upstream.port}";
                  websocket = true;
                  setHeaders.Host = hostname;
                };
              };
            })
            (attrsToList misskey-proxy));
        };
      })
    ];
}
