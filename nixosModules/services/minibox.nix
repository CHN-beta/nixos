{ lib, config, pkgs, ... }:
{
  options.nixos.services.minibox = lib.mkOption
  {
    type = lib.types.nullOr (lib.types.submodule { options =
    {
      hostname = lib.mkOption { type = lib.types.str; default = "question.chn.moe"; };
    };});
    default = null;
  };
  config = let inherit (config.nixos.services) minibox; in lib.mkIf (minibox != null)
  {
    systemd.services."minibox" = rec
    {
      after = [ "network.target" "postgresql.service" ];
      requires = after;
      wantedBy = [ "multi-user.target" ];
      serviceConfig =
      {
        User = "minibox";
        Group = "minibox";
        WorkingDirectory = "${pkgs.localPkgs.minibox}";
        ExecStart = "${pkgs.nodejs}/bin/node ${pkgs.localPkgs.minibox}/server.js";
        CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
        AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
        Restart = "always";
        EnvironmentFile = config.nixos.system.sops.templates."minibox/env".path;
      };
    };
    nixos =
    {
      system.sops =
      {
        templates."minibox/env".content = let inherit (config.nixos.system.sops) placeholder; in
        ''
          DATABASE_URL=postgresql://minibox:${placeholder."postgresql/minibox"}@localhost:5432/minibox
          ADMIN_PASSWORD=${placeholder."minibox/admin"}
          SESSION_SECRET=${placeholder."minibox/session"}
          PORT=6240
          TELEGRAM_BOT_TOKEN=${placeholder."telegram/token"}
          TELEGRAM_CHAT_ID=${placeholder."telegram/user/chn"}
        '';
        secrets = { "minibox/admin" = {}; "minibox/session" = {}; "telegram/token" = {}; "telegram/user/chn" = {}; };
      };
      services =
      {
        nginx.https.${minibox.hostname}.location."/".proxy.upstream = "http://127.0.0.1:6240";
        postgresql.instances.minibox = {};
      };
    };
    users =
    {
      users.minibox = { uid = config.nixos.user.uid.minibox; group = "minibox"; isSystemUser = true; };
      groups."minibox".gid = config.nixos.user.gid.minibox;
    };
  };
}
