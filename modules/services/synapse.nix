# port from nixpkgs#70dc536a
inputs:
{
  options.nixos.services.synapse.instances = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.attrsOf (types.submodule (submoduleInputs: { options =
    {
      autoStart = mkOption { type = types.bool; default = true; };
      port = mkOption { type = types.ints.unsigned; default = 8008; };
      redisPort = mkOption { type = types.ints.unsigned; default = 6379; };
      slidingSyncPort = mkOption { type = types.ints.unsigned; default = 9000; };
      hostname = mkOption
      {
        type = types.nonEmptyStr;
        default = "${submoduleInputs.config._module.args.name}.chn.moe";
      };
      matrixHostname = mkOption { type = types.nonEmptyStr; default = "chn.moe"; };
      slidingSyncHostname = mkOption
      {
        type = types.nonEmptyStr;
        default = "syncv3.${submoduleInputs.config.hostname}";
      };
      # , synapse_homeserver --config-path homeserver.yaml --generate-config --report-stats=yes --server-name xxx
    };}));
    default = {};
  };
  config =
    let
      inherit (inputs.config.nixos.services) synapse;
      inherit (inputs.lib) mkIf mkMerge;
      inherit (builtins) map listToAttrs replaceStrings concatLists;
      inherit (inputs.localLib) attrsToList;
    in
    {
      users = mkMerge (map
        (instance:
        {
          users."synapse-${instance.name}" =
          {
            uid = inputs.config.nixos.system.user.user."synapse-${instance.name}";
            group = "synapse-${instance.name}";
            home = "/var/lib/synapse/${instance.name}";
            createHome = true;
            isSystemUser = true;
            shell = "${inputs.pkgs.bash}/bin/bash";
          };
          groups."synapse-${instance.name}".gid = inputs.config.nixos.system.user.group."synapse-${instance.name}";
        })
        (attrsToList synapse.instances));
      systemd = mkMerge (map
        (instance: let workdir = "/var/lib/synapse/${instance.name}"; in
        {
          services =
          {
            "synapse-${instance.name}" =
              let
                package = inputs.pkgs.matrix-synapse.override
                  { extras = [ "url-preview" "postgres" "redis" ]; plugins = []; };
                config = inputs.config.sops.templates."synapse/${instance.name}/config.yaml".path;
                homeserver = "${package}/bin/synapse_homeserver";
              in
              {
                description = "synapse-${instance.name}";
                enable = instance.value.autoStart;
                after = [ "network-online.target" "postgresql.service" ];
                requires = [ "postgresql.service" ];
                wantedBy = [ "multi-user.target" ];
                serviceConfig =
                {
                  ExecStart = "${homeserver} --config-path ${config} --keys-directory ${workdir}";
                  Type = "notify";
                  User = "synapse-${instance.name}";
                  Group = "synapse-${instance.name}";
                  WorkingDirectory = workdir;
                  ExecReload = "${inputs.pkgs.util-linux}/bin/kill -HUP $MAINPID";
                  Restart = "on-failure";
                  UMask = "0077";
                  CapabilityBoundingSet = [ "" ];

                  # hardening
                  LockPersonality = true;
                  NoNewPrivileges = true;
                  PrivateDevices = true;
                  PrivateTmp = true;
                  PrivateUsers = true;
                  ProcSubset = "pid";
                  ProtectClock = true;
                  ProtectControlGroups = true;
                  ProtectHome = true;
                  ProtectHostname = true;
                  ProtectKernelLogs = true;
                  ProtectKernelModules = true;
                  ProtectKernelTunables = true;
                  ProtectProc = "invisible";
                  ProtectSystem = "strict";
                  ReadWritePaths = [ workdir ];
                  RemoveIPC = true;
                  RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
                  RestrictNamespaces = true;
                  RestrictRealtime = true;
                  RestrictSUIDSGID = true;
                  SystemCallArchitectures = "native";
                  SystemCallFilter = [ "@system-service" "~@resources" "~@privileged" ];
                };
              };
            "synapse-sliding-sync-${instance.name}" =
            {
              after = [ "synapse-${instance.name}.service" ];
              wants = [ "synapse-${instance.name}.service" ];
              wantedBy = [ "multi-user.target" ];
              serviceConfig =
              {
                User = "synapse-${instance.name}";
                Group = "synapse-${instance.name}";
                EnvironmentFile = inputs.config.sops.templates."synapse/${instance.name}-sliding-sync/env".path;
                ExecStart = inputs.lib.getExe inputs.pkgs.matrix-sliding-sync;
                WorkingDirectory = workdir + "-sliding-sync";
                Restart = "on-failure";
                RestartSec = "1s";
              };
            };
          };
          tmpfiles.rules =
          [
            "d /var/lib/synapse 0755 root root"
            "d ${workdir} 0700 synapse-${instance.name} synapse-${instance.name}"
            "Z ${workdir} - synapse-${instance.name} synapse-${instance.name}"
            "d ${workdir}-sliding-sync 0700 synapse-${instance.name} synapse-${instance.name}"
            "Z ${workdir}-sliding-sync - synapse-${instance.name} synapse-${instance.name}"
          ];
        })
        (attrsToList synapse.instances));
      sops = mkMerge (map
        (instance:
        {
          templates =
          {
            "synapse/${instance.name}/config.yaml" =
            {
              owner = "synapse-${instance.name}";
              group = "synapse-${instance.name}";
              content =
                let
                  inherit (inputs.config.sops) placeholder;
                in builtins.readFile ((inputs.pkgs.formats.yaml {}).generate "${instance.name}.yaml"
                {
                  server_name = instance.value.matrixHostname;
                  public_baseurl = "https://${instance.value.hostname}/";
                  listeners =
                  [{
                    bind_addresses = [ "127.0.0.1" ];
                    inherit (instance.value) port;
                    resources = [{ names = [ "client" "federation" ]; compress = false; }];
                    tls = false;
                    type = "http";
                    x_forwarded = true;
                  }];
                  database =
                  {
                    name = "psycopg2";
                    args =
                    {
                      user = "synapse_${replaceStrings [ "-" ] [ "_" ] instance.name}";
                      password = placeholder."postgresql/synapse_${replaceStrings [ "-" ] [ "_" ] instance.name}";
                      database = "synapse_${replaceStrings [ "-" ] [ "_" ] instance.name}";
                      host = "127.0.0.1";
                      port = "5432";
                    };
                    allow_unsafe_locale = true;
                  };
                  redis =
                  {
                    enabled = true;
                    port = instance.value.redisPort;
                    password = placeholder."redis/synapse-${instance.name}";
                  };
                  turn_shared_secret = placeholder."synapse/${instance.name}/coturn";
                  registration_shared_secret = placeholder."synapse/${instance.name}/registration";
                  macaroon_secret_key = placeholder."synapse/${instance.name}/macaroon";
                  form_secret = placeholder."synapse/${instance.name}/form";
                  signing_key_path = inputs.config.sops.secrets."synapse/${instance.name}/signing-key".path;
                  email =
                  {
                    smtp_host = "mail.chn.moe";
                    smtp_port = 25;
                    smtp_user = "bot@chn.moe";
                    smtp_pass = placeholder."mail/bot";
                    require_transport_security = true;
                    notif_from = "Your Friendly %(app)s homeserver <bot@chn.moe>";
                    app_name = "Haonan Chen's synapse";
                  };
                  admin_contact = "mailto:chn@chn.moe";
                  enable_registration = true;
                  registrations_require_3pid = [ "email" ];
                  turn_uris = [ "turns:coturn.chn.moe" "turn:coturn.chn.moe" ];
                  max_upload_size = "1024M";
                  web_client_location = "https://element.chn.moe/";
                  serve_server_wellknown = true;
                  extra_well_known_client_content."org.matrix.msc3575.proxy".url =
                    "https://${instance.value.slidingSyncHostname}";
                  report_stats = true;
                  trusted_key_servers =
                  [{
                    server_name = "matrix.org";
                    verify_keys."ed25519:auto" = "Noi6WqcDj0QmPxCNQqgezwTlBKrfqehY1u2FyWP9uYw";
                  }];
                  suppress_key_server_warning = true;
                  log_config = (inputs.pkgs.formats.yaml {}).generate "log.yaml"
                  {
                    version = 1;
                    formatters.precise.format =
                      "%(asctime)s - %(name)s - %(lineno)d - %(levelname)s - %(request)s - %(message)s";
                    handlers.console = { class = "logging.StreamHandler"; formatter = "precise"; };
                    root = { level = "INFO"; handlers = [ "console" ]; };
                    disable_existing_loggers = true;
                  };
                  pid_file = "/run/synapse-${instance.name}.pid";
                  media_store_path = "/var/lib/synapse/${instance.name}/media_store";
                  presence.enabled = true;
                  url_preview_enabled = true;
                  url_preview_ip_range_blacklist =
                  [
                    "10.0.0.0/8" "100.64.0.0/10" "127.0.0.0/8" "169.254.0.0/16" "172.16.0.0/12" "192.0.0.0/24"
                    "192.0.2.0/24" "192.168.0.0/16" "192.88.99.0/24" "198.18.0.0/15" "198.51.100.0/24" "2001:db8::/32"
                    "203.0.113.0/24" "224.0.0.0/4" "::1/128" "fc00::/7" "fe80::/10" "fec0::/10" "ff00::/8"
                  ];
                  max_image_pixels = "32M";
                  dynamic_thumbnails = false;
                });
            };
            "synapse/${instance.name}-sliding-sync/env" =
            {
              owner = "synapse-${instance.name}";
              group = "synapse-${instance.name}";
              content =
                let
                  inherit (inputs.config.sops) placeholder;
                  pgString = "postgresql://"
                    + "synapse_${replaceStrings [ "-" ] [ "_" ] instance.name}"
                    + ":${placeholder."postgresql/synapse_${replaceStrings [ "-" ] [ "_" ] instance.name}"}"
                    + "@127.0.0.1:5432"
                    + "/synapse_${replaceStrings [ "-" ] [ "_" ] instance.name}_sliding_sync"
                    + "?sslmode=disable";
                in
                ''
                  SYNCV3_SERVER=https://${instance.value.hostname}
                  SYNCV3_DB=${pgString}
                  SYNCV3_SECRET=${placeholder."synapse/${instance.name}/sliding-sync"}
                  SYNCV3_BINDADDR=127.0.0.1:${toString instance.value.slidingSyncPort}
                '';
            };
          };
          secrets = (listToAttrs (map
            (secret: { name = "synapse/${instance.name}/${secret}"; value = {}; })
            [ "coturn" "registration" "macaroon" "form" "sliding-sync" ]))
            // { "synapse/${instance.name}/signing-key".owner = "synapse-${instance.name}"; }
            // { "mail/bot" = {}; };
        })
        (attrsToList synapse.instances));
      nixos.services =
      {
        postgresql =
        {
          enable = mkIf (synapse.instances != {}) true;
          instances = listToAttrs (concatLists (map
            (instance:
            [
              {
                name = "synapse_${replaceStrings [ "-" ] [ "_" ] instance.name}";
                value.initializeFlags = { TEMPLATE = "template0"; LC_CTYPE = "C"; LC_COLLATE = "C"; };
              }
              {
                name = "synapse_${replaceStrings [ "-" ] [ "_" ] instance.name}_sliding_sync";
                value.user = "synapse_${replaceStrings [ "-" ] [ "_" ] instance.name}";
              }
            ])
            (attrsToList synapse.instances)));
        };
        redis.instances = listToAttrs (map
          (instance: { name = "synapse-${instance.name}"; value.port = instance.value.redisPort; })
          (attrsToList synapse.instances));
        nginx =
        {
          enable = mkIf (synapse.instances != {}) true;
          https = listToAttrs (concatLists (map
            (instance: with instance.value;
            [
              {
                name = hostname;
                value.location."/".proxy = { upstream = "http://127.0.0.1:${toString port}"; websocket = true; };
              }
              {
                name = slidingSyncHostname;
                value.location."/".proxy =
                  { upstream = "http://127.0.0.1:${toString slidingSyncPort}"; websocket = true; };
              }
            ])
            (attrsToList synapse.instances)));
        };
      };
    };
}
