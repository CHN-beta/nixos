{
  lib,
  config,
  pkgs,
  ...
}:
let
  package = pkgs.localPkgs.freshman-followup;
in
{
  options.nixos.services.freshman-followup = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.submodule {
        options = {
          hostname = lib.mkOption {
            type = lib.types.str;
            default = "followup.chn.moe";
            description = "Nginx HTTPS domain name for the freshman follow-up service.";
          };
          port = lib.mkOption {
            type = lib.types.port;
            default = 6250;
            description = "Internal listening port for the backend service.";
          };
        };
      }
    );
    default = null;
    description = "Freshman Follow-up System.";
  };

  config =
    let
      cfg = config.nixos.services.freshman-followup;
    in
    lib.mkIf (cfg != null) {
      systemd.services.freshman-followup = rec {
        description = "Freshman Follow-up Service Backend";
        after = [
          "network.target"
          "postgresql.service"
        ];
        requires = after;
        wantedBy = [ "multi-user.target" ];
        restartTriggers = [
          config.nixos.system.sops.templates."freshman-followup/config.yaml".file
        ];
        serviceConfig = {
          User = "freshman-followup";
          Group = "freshman-followup";
          Restart = "always";
          RestartSec = 5;
          ExecStart = "${package.backend}/bin/freshman-followup ${config.nixos.system.sops.templates."freshman-followup/config.yaml".path}";

          # Hardening
          CapabilityBoundingSet = [ "" ];
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
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_UNIX"
          ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          SystemCallArchitectures = "native";
        };
      };

      nixos = {
        system.sops = {
          templates."freshman-followup/config.yaml" = {
            owner = "freshman-followup";
            content =
              let
                inherit (config.nixos.system.sops) placeholder;
              in
              ''
                database_url: "postgres://hf:${placeholder."postgresql/hf"}@localhost:5432/hf"
                jwt_secret: "${placeholder."freshman-followup/jwt_secret"}"
                host: "127.0.0.1"
                port: ${builtins.toString cfg.port}
              '';
          };
          secrets = {
            "freshman-followup/jwt_secret" = { };
          };
        };

        services = {
          # Nginx 统一路由：静态文件挂载在 /ui/，接口反代至 /api/
          nginx.https.${cfg.hostname} = {
            location = {
              "= /".return.return = "302 /ui/";
              "= /ui".return.return = "302 /ui/";
              "/ui/".static = {
                root = "${package.ui}/lib/freshman-followup-ui";
                index = [ "index.html" ];
                tryFiles = [
                  "$uri"
                  "$uri/"
                  "/ui/index.html"
                ];
              };
              "/api/".proxy = {
                upstream = "http://127.0.0.1:${builtins.toString cfg.port}/api/";
              };
            };
          };

          # 声明式 PostgreSQL 数据库实例
          postgresql.instances.hf = { };
        };
      };

      users = {
        users.freshman-followup = {
          uid = config.nixos.user.uid.freshman-followup;
          group = "freshman-followup";
          isSystemUser = true;
        };
        groups.freshman-followup.gid = config.nixos.user.gid.freshman-followup;
      };
    };
}
