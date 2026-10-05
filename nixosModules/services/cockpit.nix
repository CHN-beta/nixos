{
  lib,
  config,
  pkgs,
  ...
}:
let
  inherit (config.nixos.services) cockpit;
in
{
  options.nixos.services.cockpit = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.submodule {
        options = {
          hostname = lib.mkOption {
            type = lib.types.str;
            default = "shell.chn.moe";
            description = "Domain name for Cockpit web service.";
          };
          port = lib.mkOption {
            type = lib.types.port;
            default = 9090;
            description = "Internal port Cockpit listens on.";
          };
          allowedUsers = lib.mkOption {
            type = lib.types.nullOr (lib.types.listOf lib.types.str);
            default = [ "straycat" ];
            description = "List of users allowed to log in via Cockpit. Set to null or [] to allow all users.";
          };
        };
      }
    );
    default = null;
    description = "Cockpit web-based graphical interface for servers.";
  };

  config = lib.mkIf (cockpit != null) {
    services.cockpit = {
      enable = true;
      port = cockpit.port;
      allowed-origins = [
        "https://${cockpit.hostname}"
        "wss://${cockpit.hostname}"
      ];
      settings = {
        WebService = {
          ProtocolHeader = "X-Forwarded-Proto";
          ForwardedForHeader = "X-Forwarded-For";
          AllowUnencrypted = true;
          LoginTo = false;
        };
      };
    };

    security.pam.services.cockpit.rules = lib.mkIf (cockpit.allowedUsers != null && cockpit.allowedUsers != [ ]) {
      auth.restrict-user = {
        order = config.security.pam.services.cockpit.rules.auth.unix.order - 1000;
        control = "requisite";
        modulePath = "${pkgs.linux-pam}/lib/security/pam_succeed_if.so";
        args =
          if (builtins.length cockpit.allowedUsers == 1) then
            [
              "user"
              "="
              (builtins.head cockpit.allowedUsers)
            ]
          else
            [
              "user"
              "in"
              (builtins.concatStringsSep ":" cockpit.allowedUsers)
            ];
      };
      account.restrict-user = {
        order = config.security.pam.services.cockpit.rules.account.unix.order - 1000;
        control = "requisite";
        modulePath = "${pkgs.linux-pam}/lib/security/pam_succeed_if.so";
        args =
          if (builtins.length cockpit.allowedUsers == 1) then
            [
              "user"
              "="
              (builtins.head cockpit.allowedUsers)
            ]
          else
            [
              "user"
              "in"
              (builtins.concatStringsSep ":" cockpit.allowedUsers)
            ];
      };
    };

    nixos.services.nginx.https.${cockpit.hostname} = {
      global.extraConfig = ''
        proxy_buffering off;
        gzip off;
      '';
      location."/".proxy.upstream = "http://127.0.0.1:${toString cockpit.port}";
    };
  };
}
