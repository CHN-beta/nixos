inputs:
{
  options.nixos.services.misskey.instances = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.attrsOf (types.submodule { options =
    {
      port = mkOption { type = types.ints.unsigned; default = 9726; };
      redis.port = mkOption { type = types.ints.unsigned; default = 3545; };
      hostname = mkOption { type = types.nonEmptyStr; default = "misskey.chn.moe"; };
    };});
    default = {};
  };
  config = let inherit (inputs.config.nixos.services) misskey; in
  {
    systemd = inputs.lib.mkMerge (builtins.map
      (instance:
      {
        services."misskey-${instance.name}" = rec
        {
          description = "misskey ${instance.name}";
          after = [ "network.target" "redis-misskey-${instance.name}.service" "postgresql.service" ];
          requires = after;
          wantedBy = [ "multi-user.target" ];
          environment.MISSKEY_CONFIG_JSON =
            inputs.config.nixos.system.sops.templates."misskey/${instance.name}.json".path;
          serviceConfig = rec
          {
            User = "misskey-${instance.name}";
            Group = "misskey-${instance.name}";
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
      (inputs.lib.attrsToList misskey.instances));
    fileSystems = inputs.lib.mkMerge (builtins.map
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
      (inputs.lib.attrsToList misskey.instances));
    users = inputs.lib.mkMerge (builtins.map
      (instance:
      {
        users."misskey-${instance.name}" =
        {
          uid = inputs.config.nixos.user.uid."misskey-${instance.name}";
          group = "misskey-${instance.name}";
          home = "/var/lib/misskey/${instance.name}";
          createHome = true;
          isSystemUser = true;
        };
        groups."misskey-${instance.name}".gid = inputs.config.nixos.user.gid."misskey-${instance.name}";
      })
      (inputs.lib.attrsToList misskey.instances));
    nixos =
    {
      services =
      {
        redis.instances = builtins.listToAttrs (builtins.map
          (instance: { name = "misskey-${instance.name}"; value.port = instance.value.redis.port; })
          (inputs.lib.attrsToList misskey.instances));
        postgresql.instances = builtins.listToAttrs (builtins.map
          (instance: { name = "misskey_${builtins.replaceStrings [ "-" ] [ "_" ] instance.name}"; value = {}; })
          (inputs.lib.attrsToList misskey.instances));
        nginx.https = builtins.listToAttrs (builtins.map
          (instance: with instance.value;
          {
            name = hostname;
            value.location."/".proxy = { upstream = "http://127.0.0.1:${toString port}"; websocket = true; };
          })
          (inputs.lib.attrsToList misskey.instances));
      };
      system.sops.templates = builtins.listToAttrs (builtins.map
        (instance:
        {
          name = "misskey/${instance.name}.json";
          value =
          {
            content =
              let
                placeholder = inputs.config.nixos.system.sops.placeholder;
                redis = inputs.config.nixos.services.redis.instances."misskey-${instance.name}";
              in builtins.toJSON
              {
                url = "https://${instance.value.hostname}/";
                port = builtins.toString instance.value.port;
                db =
                {
                  host = "127.0.0.1";
                  port = 5432;
                  db = "misskey_${builtins.replaceStrings [ "-" ] [ "_" ] instance.name}";
                  user = "misskey_${builtins.replaceStrings [ "-" ] [ "_" ] instance.name}";
                  pass = placeholder."postgresql/misskey_${builtins.replaceStrings [ "-" ] [ "_" ] instance.name}";
                  extra.statement_timeout = 600000;
                };
                dbReplications = false;
                redis =
                {
                  host = "127.0.0.1";
                  port = builtins.toString redis.port;
                  pass = placeholder."redis/misskey-${instance.name}";
                };
                id = "aid";
                proxyBypassHosts =
                [
                  "api.deepl.com"
                  "api-free.deepl.com"
                  "www.recaptcha.net"
                  "hcaptcha.com"
                  "challenges.cloudflare.com"
                ];
                proxyRemoteFiles = true;
                signToActivityPubGet = true;
                maxFileSize = 1073741824;
                fulltextSearch.provider = "sqlPgroonga";
              };
            owner = "misskey-${instance.name}";
          };
        })
        (inputs.lib.attrsToList misskey.instances));
    };
  };
}
