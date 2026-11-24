{
  config,
  lib,
  pkgs,
  ...
}:
let
  users = [
    "chn"
    "cecilia"
  ];
in
{
  config = {
    users = {
      groups.mirism = { };
      users = {
        mirism = {
          isSystemUser = true;
          group = "mirism";
        };
        nginx.extraGroups = [ "mirism" ];
      };
    };
    systemd.services.mirism = {
      description = "Mirism authenticated mirror proxy";
      wantedBy = [ "multi-user.target" ];
      after = [ "authelia-mirism.service" ];
      wants = [ "authelia-mirism.service" ];
      serviceConfig = {
        User = "mirism";
        Group = "mirism";
        RuntimeDirectory = "mirism";
        RuntimeDirectoryMode = "0750";
        ExecStart = "${lib.getExe pkgs.localPkgs.mirism} --config ${
          pkgs.writeText "mirism-config.json" (
            builtins.toJSON {
              uds_path = "/run/mirism/mirism.sock";
              mirism_host = "mirism.one";
              authelia_url = "http://127.0.0.1:9091";
              authelia_login_url = "https://auth.mirism.one/";
              trust_remote_user_header = false;
              min_device_lifetime_secs = 3600;
              rt_rotation_secs = 600;
            }
          )
        }";
        Restart = "on-failure";
      };
    };
    services.authelia.instances.mirism = {
      enable = true;
      secrets =
        let
          inherit (config.nixos.system.sops) secrets;
        in
        {
          jwtSecretFile = secrets."authelia-mirism/jwt-secret".path;
          sessionSecretFile = secrets."authelia-mirism/session-secret".path;
          storageEncryptionKeyFile = secrets."authelia-mirism/storage-encryption-key".path;
        };
      settings = {
        log.level = "info";
        server.address = "tcp://127.0.0.1:9091/";
        server.endpoints.authz.forward-auth.implementation = "ForwardAuth";
        totp.disable = true;
        webauthn.disable = true;
        duo_api.disable = true;
        authentication_backend = {
          password_reset.disable = true;
          password_change.disable = true;
          file.path = config.nixos.system.sops.templates."authelia-mirism/users.yml".path;
        };
        access_control = {
          default_policy = "deny";
          rules = [
            {
              domain = "mirism.one";
              policy = "one_factor";
            }
          ];
        };
        session.cookies = [
          {
            name = "authelia_session";
            domain = "mirism.one";
            authelia_url = "https://auth.mirism.one";
            default_redirection_url = "https://mirism.one";
          }
        ];
        storage.local.path = "/var/lib/authelia-mirism/db.sqlite3";
        notifier.filesystem.filename = "/var/lib/authelia-mirism/notification.txt";
      };
    };
    systemd.services.authelia-mirism.restartTriggers = [
      config.nixos.system.sops.templates."authelia-mirism/users.yml".content
    ];
    nixos = {
      services.nginx.https = {
        "mirism.one".location."/".proxy.upstream = "http://unix:/run/mirism/mirism.sock:";
        "auth.mirism.one".location."/".proxy.upstream = "http://127.0.0.1:9091";
      };
      system.sops = {
        secrets = lib.mkMerge [
          (
            [
              "jwt-secret"
              "session-secret"
              "storage-encryption-key"
            ]
            |> lib.flip lib.genAttrs' (
              n:
              lib.nameValuePair "authelia-mirism/${n}" {
                owner = config.services.authelia.instances.mirism.user;
              }
            )
          )
          (users |> lib.flip lib.genAttrs' (n: lib.nameValuePair "authelia-mirism/users/${n}" { }))
        ];
        templates = {
          "authelia-mirism/users.yml" = {
            owner = config.services.authelia.instances.mirism.user;
            content = builtins.toJSON {
              users =
                users
                |> lib.flip lib.genAttrs (n: {
                  displayname = n;
                  password = config.nixos.system.sops.placeholder."authelia-mirism/users/${n}";
                  email = "${n}@chn.moe";
                });
            };
          };
        };
      };
    };
  };
}
