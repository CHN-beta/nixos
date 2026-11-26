{
  config,
  lib,
  pkgs,
  ...
}:
let
  # `ddml auth` is global and unique; every other process is bound 1:1 to a
  # single plant/system (core red line). The endpoints below are the single
  # source of truth for the config override, the systemd units and nginx: no
  # two networks may ever share a socket path or a TCP port, including two
  # systems hosted under the same plant.
  authPort = 3101;
  plants = {
    fj1.systems.bf1 = {
      webPort = 3100;
      simPort = 3102;
    };
    nm1.systems = {
      bf2 = {
        webPort = 3103;
        simPort = 3104;
      };
      bof2_2 = {
        webPort = 3105;
        simPort = 3106;
      };
      bof2_3 = {
        webPort = 3107;
        simPort = 3108;
      };
    };
  };
  instances = lib.concatMapAttrs (
    plant: plantConfig:
    lib.mapAttrs' (
      system: systemConfig:
      lib.nameValuePair "${plant}-${system}" {
        inherit plant system;
        inherit (systemConfig) webPort simPort;
        name = "${plant}-${system}";
        coreSocket = "/run/ddml/core-${plant}-${system}.sock";
        simSocket = "/run/ddml/sim_plc-${plant}-${system}.sock";
      }
    ) plantConfig.systems
  ) plants;
  # Later files recursively override earlier ones (see mergeYamlConfigs), so
  # only the per-network transport endpoints are redeclared here.
  configOverride = {
    auth = {
      jwt_public_key = "MCowBQYDK2VwAyEAATfJ+buLhkS7vCch7XOaoe+7gnmv4Ljbo8QhpvI+wrI=";
      listen = "127.0.0.1:${toString authPort}";
    };
    plants = lib.mapAttrs (plant: plantConfig: {
      systems = lib.mapAttrs (system: systemConfig: {
        control = {
          core_socket = instances."${plant}-${system}".coreSocket;
          sim_hardware_socket = instances."${plant}-${system}".simSocket;
          web_listen = "127.0.0.1:${toString systemConfig.webPort}";
          sim_listen = "127.0.0.1:${toString systemConfig.simPort}";
        };
      }) plantConfig.systems;
    }) plants;
  };
in
{
  users = {
    users.ddml-service = {
      isSystemUser = true;
      uid = config.nixos.user.uid.ddml-service;
      group = "ddml-service";
    };
    groups.ddml-service.gid = config.nixos.user.gid.ddml-service;
  };

  # One shared runtime directory for every network. `RuntimeDirectory=` is
  # deliberately not used: systemd removes a unit's runtime directory when that
  # unit stops/restarts, which would delete the other networks' live sockets.
  systemd.tmpfiles.rules = [ "d /run/ddml 0700 ddml-service ddml-service -" ];

  systemd.services =
    let
      commonServiceConfig = {
        User = "ddml-service";
        Group = "ddml-service";
        Restart = "on-failure";
        RestartSec = 5;
        UMask = "0077";
        # Journald keeps info/warn/error by default: the drift fitter, solver and
        # hardware summaries only reach the journal at info level, and an
        # operator debugging a stalled network must not have to restart units.
        Environment = "RUST_LOG=info";

        CapabilityBoundingSet = [ "" ];
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RemoveIPC = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [ "@system-service" ];
      };
      configOverrideYaml = (pkgs.formats.yaml { }).generate "ddml-config-override.yaml" configOverride;
      configYaml = pkgs.localPkgs.ddml.mergeYamlConfigs [
        "${pkgs.localPkgs.ddml.backend.src}/config.yaml"
        configOverrideYaml
      ];
      configFlags = "--config ${configYaml}";
      secretFlags = "--secrets ${config.nixos.system.sops.templates."ddml/secrets.yaml".path}";
      backend = "${pkgs.localPkgs.ddml.backend}/bin/ddml";
      # One migrate/sim/core/web quadruple per network, each bound to its own
      # plant/system. The global `ddml-migrate` only seeds `public.*`; every
      # tenant schema is upgraded by its own oneshot unit so a single broken
      # network cannot block the others.
      instanceServices = lib.concatMapAttrs (
        _: instance:
        let
          migrateService = "ddml-migrate-${instance.name}.service";
          coreService = "ddml-core-${instance.name}.service";
          scopeFlags = "-p ${instance.plant} -s ${instance.system}";
        in
        {
          "ddml-migrate-${instance.name}" = {
            description = "DDML Tenant Database Migration (${instance.name})";
            after = [ "ddml-migrate.service" ];
            requires = [ "ddml-migrate.service" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = commonServiceConfig // {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = "${backend} migrate plant ${scopeFlags} ${configFlags} ${secretFlags}";
            };
          };
          "ddml-sim-${instance.name}" = {
            description = "DDML Duct Network Simulation Service (${instance.name})";
            after = [ "network.target" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = commonServiceConfig // {
              ExecStartPre = "${pkgs.coreutils}/bin/rm -f ${instance.simSocket}";
              ExecStart = "${backend} sim ${scopeFlags} ${configFlags}";
            };
          };
          "ddml-core-${instance.name}" = {
            description = "DDML Core Control Engine (${instance.name})";
            after = [
              migrateService
              "ddml-sim-${instance.name}.service"
            ];
            requires = [ migrateService ];
            wants = [ "ddml-sim-${instance.name}.service" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = commonServiceConfig // {
              ExecStartPre = "${pkgs.coreutils}/bin/rm -f ${instance.coreSocket}";
              ExecStart = "${backend} core ${scopeFlags} ${configFlags} ${secretFlags}";
            };
          };
          "ddml-web-${instance.name}" = {
            description = "DDML Web Gateway Service (${instance.name})";
            after = [
              coreService
              migrateService
            ];
            requires = [
              coreService
              migrateService
            ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = commonServiceConfig // {
              ExecStart = "${backend} web ${scopeFlags} ${configFlags} ${secretFlags}";
            };
          };
        }
      ) instances;
    in
    {
      ddml-migrate = {
        description = "DDML Global Database Migrations";
        after = [
          "postgresql.service"
          "postgresql-setup.service"
        ];
        requires = [ "postgresql.service" ];
        wants = [ "postgresql-setup.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = commonServiceConfig // {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${backend} migrate global ${configFlags} ${secretFlags}";
        };
      };
      ddml-auth = {
        description = "DDML Authentication Service";
        after = [ "ddml-migrate.service" ];
        requires = [ "ddml-migrate.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = commonServiceConfig // {
          ExecStart = "${backend} auth ${configFlags} ${secretFlags}";
        };
      };
    }
    // instanceServices;
  nixos = {
    system.sops = {
      templates."ddml/secrets.yaml" = {
        owner = "ddml-service";
        group = "ddml-service";
        mode = "0400";
        content =
          let
            p = config.nixos.system.sops.placeholder;
          in
          ''
            auth:
              ed25519_private_key: "${p."ddml/auth"}"
              initial_admin_password: "${p."ddml/admin"}"
            database:
              password: "${p."postgresql/ddml"}"
          '';
      };
      secrets."ddml/auth" = { };
      secrets."ddml/admin" = { };
    };
    services = {
      postgresql.instances.ddml = { };
      nginx.https."ddml.chn.moe".location = {
        "= /".return.return = "302 /ui/";
        "= /ui".return.return = "302 /ui/";
        "/ui/".static = {
          root = "${pkgs.localPkgs.ddml.frontend}/lib/ddml-ui";
          index = [ "index.html" ];
          tryFiles = [
            "$uri"
            "$uri/"
            "=404"
          ];
        };
        "^~ /ui/assets/".static = {
          root = "${pkgs.localPkgs.ddml.frontend}/lib/ddml-ui";
          tryFiles = [
            "$uri"
            "=404"
          ];
          extraConfig = ''
            expires off;
            add_header Cache-Control "public, max-age=31536000, immutable";
          '';
        };
        # Every documentation artifact (HTML manual, PDF, changelog,
        # Rustdoc, OpenAPI/Scalar) is published under `$out/doc/`, so one
        # static route serves the whole tree.
        "= /doc".return.return = "302 /doc/";
        "/doc/".static = {
          root = "${pkgs.localPkgs.ddml.doc}";
          index = [ "index.html" ];
          tryFiles = [
            "$uri"
            "$uri/"
            "=404"
          ];
        };
        "/auth/".proxy = {
          upstream = "http://127.0.0.1:${toString authPort}";
          websocket = false;
        };
      }
      # Each network owns /api/plants/<p>/systems/<s>/ and
      # /sim/plants/<p>/systems/<s>/; the full original URI is forwarded
      # verbatim (no trailing slash on the upstream).
      // lib.concatMapAttrs (_: instance: {
        "/api/plants/${instance.plant}/systems/${instance.system}/".proxy = {
          upstream = "http://127.0.0.1:${toString instance.webPort}";
          websocket = true;
        };
        "/sim/plants/${instance.plant}/systems/${instance.system}/".proxy = {
          upstream = "http://127.0.0.1:${toString instance.simPort}";
          websocket = true;
        };
      }) instances;
    };
  };
}
