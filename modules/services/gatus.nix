{ lib, config, topInputs, ... }:
{
  options.nixos.services.gatus = lib.mkOption
    { type = lib.types.nullOr (lib.types.submodule {}); default = null; };
  config = let inherit (config.nixos.services) gatus; in lib.mkIf (gatus != null)
  {
    services.gatus =
    {
      enable = true;
      settings =
      {
        storage =
        {
          type = "postgresql";
          path = "postgres://gatus:\${DB_PASSWORD}@127.0.0.1:5432/gatus?sslmode=disable";
          maximum-number-of-results = 10 * 365 * 24 * 60;
          maximum-number-of-events = 10000;
        };
        alerting.telegram = 
        {
          token = "\${TELEGRAM_BOT_TOKEN}";
          id = "\${TELEGRAM_CHAT_ID}";
          default-alert =
          {
            enable = true;
            failure-threshold = 5;
            success-threshold = 1;
            send-on-resolved = true;
          };
        };
        web.port = 6935;
        ui.default-sort-by = "group";
        endpoints = builtins.concatLists
        [
          (builtins.map
            (h:
            {
              name = "tinc ${h}";
              group = "tinc";
              url = "icmp://${topInputs.self.config.dns."chn.moe".getAddress "tinc0.${h}"}";
              interval = "1m";
              conditions = [ "[CONNECTED] == true" ];
              alerts = [{ type = "telegram"; }];
            })
            [ "vps4" "vps6" "vps9" ])
          (builtins.map
            (h:
            {
              name = "tailscale ${h}";
              group = "tailscale";
              url = "icmp://${h}.ts.chn.moe";
              interval = "1m";
              conditions = [ "[CONNECTED] == true" ];
              alerts = [{ type = "telegram"; }];
            })
            [ "vps4" "vps6" "vps9" ])
        ];
      };
      environmentFile = config.nixos.system.sops.templates."gatus.env".path;
    };
    nixos =
    {
      system.sops =
      {
        templates."gatus.env".content = let inherit (config.nixos.system.sops) placeholder; in
        ''
          DB_PASSWORD=${placeholder."postgresql/gatus"}
          TELEGRAM_BOT_TOKEN=${placeholder."telegram/token"}
          TELEGRAM_CHAT_ID=${placeholder."telegram/user/chn"}
        '';
        secrets = { "telegram/token" = {}; "telegram/user/chn" = {}; };
      };
      services =
      {
        postgresql.instances.gatus = {};
        nginx.https."status.chn.moe".location."/".proxy =
        {
          upstream = "http://127.0.0.1:${builtins.toString config.services.gatus.settings.web.port}";
          websocket = true;
        };
      };
    };
  };
}
