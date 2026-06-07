{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.nixos.services.gatus = lib.mkOption {
    type = lib.types.nullOr (lib.types.submodule { });
    default = null;
  };
  config =
    let
      inherit (config.nixos.services) gatus;
    in
    lib.mkIf (gatus != null) {
      services.gatus = {
        enable = true;
        settings = {
          storage = {
            type = "postgres";
            caching = true;
            path = "postgres://gatus:\${DB_PASSWORD}@127.0.0.1:5432/gatus?sslmode=disable";
            maximum-number-of-results = 10 * 365 * 24 * 60;
            maximum-number-of-events = 10000;
          };
          alerting.telegram = {
            token = "\${TELEGRAM_BOT_TOKEN}";
            id = "\${TELEGRAM_CHAT_ID}";
            default-alert = {
              enable = true;
              failure-threshold = 10;
              success-threshold = 1;
              send-on-resolved = true;
            };
          };
          web.port = 6935;
          ui.default-sort-by = "group";
          endpoints = builtins.concatLists [
            (builtins.map
              (h: {
                name = "tinc ${h}";
                group = "tinc";
                url = "icmp://${pkgs.localPkgs.getAddress "tinc0.${h}"}";
                interval = "1m";
                conditions = [ "[CONNECTED] == true" ];
                alerts = [ { type = "telegram"; } ];
              })
              [
                "vps4"
                "vps6"
                "vps9"
                "vps10"
                "nas"
                "srv1-node0"
                "srv1-node1"
                "srv1-node2"
                "srv2-node0"
                "srv2-node1"
                "srv2-node2"
              ]
            )
            (builtins.map
              (h: {
                name = "tailscale ${h}";
                group = "tailscale";
                url = "icmp://${h}.ts.chn.moe";
                interval = "1m";
                conditions = [ "[CONNECTED] == true" ];
                alerts = [ { type = "telegram"; } ];
              })
              [
                "vps4"
                "vps6"
                "vps9"
                "vps10"
                "nas"
                "srv1-node0"
                "srv1-node1"
                "srv1-node2"
                "srv2-node0"
                "srv2-node1"
                "srv2-node2"
              ]
            )
            [
              {
                name = "tinc pc";
                group = "tinc";
                url = "icmp://${pkgs.localPkgs.getAddress "tinc0.pc"}";
                interval = "1m";
                conditions = [ "[CONNECTED] == true" ];
              }
              {
                name = "tailscale pc";
                group = "tailscale";
                url = "icmp://pc.ts.chn.moe";
                interval = "1m";
                conditions = [ "[CONNECTED] == true" ];
              }
            ]
            (builtins.map
              (h: {
                name = "${h}.chn.moe";
                group = "web";
                url = "https://${h}.chn.moe";
                interval = "1m";
                conditions = [ "[STATUS] == any(200, 418, 400)" ];
                alerts = [ { type = "telegram"; } ];
              })
              [
                "git"
                "铜锣湾"
                "matrix"
                "vaultwarden"
                "photo"
                "nextcloud"
                "xserver2"
              ]
            )
          ];
        };
        environmentFile = config.nixos.system.sops.templates."gatus.env".path;
      };
      nixos = {
        system.sops = {
          templates."gatus.env".content =
            let
              inherit (config.nixos.system.sops) placeholder;
            in
            ''
              DB_PASSWORD=${placeholder."postgresql/gatus"}
              TELEGRAM_BOT_TOKEN=${placeholder."telegram/token"}
              TELEGRAM_CHAT_ID=${placeholder."telegram/user/chn"}
            '';
          secrets = {
            "telegram/token" = { };
            "telegram/user/chn" = { };
          };
        };
        services = {
          postgresql.instances.gatus = { };
          nginx.https."status.chn.moe".location."/".proxy.upstream =
            "http://127.0.0.1:${builtins.toString config.services.gatus.settings.web.port}";
        };
      };
    };
}
