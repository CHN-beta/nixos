inputs:
{
  options.nixos.services.misskey.instances = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.attrsOf (types.submodule { options =
    {
      autoStart = mkOption { type = types.bool; default = true; };
      port = mkOption { type = types.ints.unsigned; default = 9726; };
      redis.port = mkOption { type = types.ints.unsigned; default = 3545; };
      hostname = mkOption { type = types.nonEmptyStr; default = "misskey.chn.moe"; };
      meilisearch =
      {
        enable = mkOption { type = types.bool; default = true; };
        port = mkOption { type = types.ints.unsigned; default = 7700; };
      };
    };});
    default = {};
  };
  config =
    let
      inherit (inputs.config.nixos.services) misskey;
      inherit (inputs.localLib) attrsToList;
      inherit (inputs.lib) mkMerge mkIf;
      inherit (builtins) map listToAttrs toString replaceStrings filter;
    in
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
            };
          };
          tmpfiles.rules = let dir = "/var/lib/misskey/${instance.name}/files"; owner = "misskey-${instance.name}"; in
            [ "d ${dir} 0700 ${owner} ${owner}" "Z ${dir} - ${owner} ${owner}" ];
        })
        (attrsToList misskey.instances));
      fileSystems = mkMerge (map
        (instance:
        {
          "/var/lib/misskey/${instance.name}/work" =
          {
            device = "${inputs.pkgs.localPackages.misskey}";
            options = [ "bind" "private" "x-gvfs-hide" "X-fstrim.notrim" ];
          };
          "/var/lib/misskey/${instance.name}/work/files" =
          {
            device = "/var/lib/misskey/${instance.name}/files";
            options = [ "bind" "private" "x-gvfs-hide" "X-fstrim.notrim" ];
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
                    statement_timeout: 600000
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
                  scope: global
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
            uid = inputs.config.nixos.system.user.user."misskey-${instance.name}";
            group = "misskey-${instance.name}";
            home = "/var/lib/misskey/${instance.name}";
            createHome = true;
            isSystemUser = true;
          };
          groups."misskey-${instance.name}".gid = inputs.config.nixos.system.user.group."misskey-${instance.name}";
        })
        (attrsToList misskey.instances));
      nixos.services =
      {
        redis.instances = listToAttrs (map
          (instance: { name = "misskey-${instance.name}"; value.port = instance.value.redis.port; })
          (attrsToList misskey.instances));
        postgresql =
        {
          enable = mkIf (misskey.instances != {}) true;
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
          (filter (instance: instance.value.meilisearch.enable) (attrsToList misskey.instances)));
        nginx =
        {
          enable = mkIf (misskey.instances != {}) true;
          https = listToAttrs (map
            (instance: with instance.value;
            {
              name = hostname;
              value.location."/".proxy = { upstream = "http://127.0.0.1:${toString port}"; websocket = true; };
            })
            (attrsToList misskey.instances));
        };
      };
    };
}
