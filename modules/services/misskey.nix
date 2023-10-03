inputs:
{
  options.nixos.services = let inherit (inputs.lib) mkOption types; in
  {
    misskey.instances = mkOption
    {
      type = types.attrsOf (types.submodule { options =
      {
        autoStart = mkOption { type = types.bool; default = true; };
        port = mkOption { type = types.ints.unsigned; default = 9726; };
        redis.port = mkOption { type = types.ints.unsigned; default = 3545; };
        hostname = mkOption { type = types.str; default = "misskey.chn.moe"; };
        meilisearch =
        {
          enable = mkOption { type = types.bool; default = true; };
          port = mkOption { type = types.ints.unsigned; default = 7700; };
        };
      };});
      default = {};
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
      {
        systemd = mkMerge (map
          (instance:
          {
            services."misskey-${instance.name}" = rec
            {
              enable = instance.value.autoStart;
              description = "misskey ${instance.name}";
              after = [ "network.target" "redis-misskey-${instance.name}.service" "postgresql.service" ]
                ++ (if instance.value.meilisearch.enable then [ "meilisearch-misskey-${instance.name}.service" ]
                  else []);
              requires = after;
              wantedBy = [ "multi-user.target" ];
              environment.MISSKEY_CONFIG_YML = inputs.config.sops.templates."misskey/${instance.name}.yml".path;
              serviceConfig = rec
              {
                User = inputs.config.users.users."misskey-${instance.name}".name;
                Group = inputs.config.users.users."misskey-${instance.name}".group;
                WorkingDirectory = "/var/lib/misskey/${instance.name}/work";
                ExecStart = "${WorkingDirectory}/bin/misskey";
                CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
                AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
                Restart = "always";
                RuntimeMaxSec = "1d";
              };
            };
            tmpfiles.rules =
              [ "d /var/lib/misskey/${instance.name}/files 0700 misskey-${instance.name} misskey-${instance.name}" ];
          })
          (attrsToList misskey.instances));
        fileSystems = mkMerge (map
          (instance:
          {
            "/var/lib/misskey/${instance.name}/work" =
            {
              device = "${inputs.pkgs.localPackages.misskey}";
              options = [ "bind" "private" "x-gvfs-hide" ];
            };
            "/var/lib/misskey/${instance.name}/work/files" =
            {
              device = "/var/lib/misskey/${instance.name}/files";
              options = [ "bind" "private" "x-gvfs-hide" ];
            };
          })
          (attrsToList misskey.instances));
        sops.templates = listToAttrs (map
          (instance:
          {
            name = "misskey/${instance.name}.yml";
            value =
            {
              content =
                let
                  placeholder = inputs.config.sops.placeholder;
                  redis = inputs.config.nixos.services.redis.instances."misskey-${instance.name}";
                  meilisearch = inputs.config.nixos.services.meilisearch.instances."misskey-${instance.name}";
                in
                ''
                  url: https://${instance.value.hostname}/
                  port: ${toString instance.value.port}
                  db:
                    host: 127.0.0.1
                    port: 5432
                    db: misskey_${replaceStrings [ "-" ] [ "_" ] instance.name}
                    user: misskey_${replaceStrings [ "-" ] [ "_" ] instance.name}
                    pass: ${placeholder."postgresql/misskey_${replaceStrings [ "-" ] [ "_" ] instance.name}"}
                    extra:
                      statement_timeout: 60000
                  dbReplications: false
                  redis:
                    host: 127.0.0.1
                    port: ${toString redis.port}
                    pass: ${placeholder."redis/misskey-${instance.name}"}
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
                ''
                + (if instance.value.meilisearch.enable then
                ''
                  meilisearch:
                    host: 127.0.0.1
                    port: ${toString meilisearch.port}
                    apiKey: ${placeholder."meilisearch/misskey-${instance.name}"}
                    ssl: false
                    index: misskey
                    scope: globa
                '' else "");
              owner = inputs.config.users.users."misskey-${instance.name}".name;
            };
          })
          (attrsToList misskey.instances));
        users = mkMerge (map
          (instance:
          {
            users."misskey-${instance.name}" =
            {
              isSystemUser = true;
              group = "misskey-${instance.name}";
              home = "/var/lib/misskey/${instance.name}";
              createHome = true;
            };
            groups."misskey-${instance.name}" = {};
          })
          (attrsToList misskey.instances));
        nixos.services =
        {
          redis.instances = listToAttrs (map
            (instance:
            {
              name = "misskey-${instance.name}";
              value.port = instance.value.redis.port;
            })
            (attrsToList misskey.instances));
          postgresql =
          {
            enable = true;
            instances = listToAttrs (map
              (instance: { name = "misskey_${replaceStrings [ "-" ] [ "_" ] instance.name}"; value = {}; })
              (attrsToList misskey.instances));
          };
          meilisearch.instances = listToAttrs (map
            (instance:
            {
              name = "misskey-${instance.name}";
              value =
              {
                user = inputs.config.users.users."misskey-${instance.name}".name;
                port = instance.value.meilisearch.port;
              };
            })
            (attrsToList misskey.instances));
        };
      }
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
