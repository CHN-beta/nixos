{ config, lib, ... }:
{
  options.nixos.services.authelia = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.submodule (submoduleInputs: {
        options = {
          users = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };
          clients = lib.mkOption {
            type = lib.types.listOf (
              lib.types.submodule {
                options = {
                  clientId = lib.mkOption {
                    type = lib.types.str;
                  };
                  clientName = lib.mkOption {
                    type = lib.types.str;
                  };
                  redirectUris = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                  };
                };
              }
            );
            default = [ ];
          };
          hostname = lib.mkOption {
            type = lib.types.str;
            default = "auth.chn.moe";
          };
        };
      })
    );
    default = null;
  };
  config =
    let
      inherit (config.nixos.services) authelia;
    in
    lib.mkIf (authelia != null) {
      services.authelia.instances.main = {
        enable = true;
        secrets =
          let
            inherit (config.nixos.system.sops) secrets;
          in
          {
            jwtSecretFile = secrets."authelia/jwt-secret".path;
            sessionSecretFile = secrets."authelia/session-secret".path;
            storageEncryptionKeyFile = secrets."authelia/storage-encryption-key".path;
            oidcHmacSecretFile = secrets."authelia/oidc-hmac-secret".path;
            oidcIssuerPrivateKeyFile = secrets."authelia/oidc-issuer-private-key".path;
          };
        environmentVariables =
          let
            inherit (config.nixos.system.sops) secrets;
          in
          {
            AUTHELIA_SESSION_REDIS_PASSWORD_FILE = secrets."redis/authelia".path;
            AUTHELIA_STORAGE_POSTGRES_PASSWORD_FILE = secrets."authelia/db".path;
          };
        settingsFiles = [ config.nixos.system.sops.templates."authelia/oidc-clients.yml".path ];
        settings = {
          theme = "light";
          server = {
            # unix socket: umask 0007 makes it 0770, so nginx (member of the authelia-main group) can connect
            address = "unix:///run/authelia-main/authelia.sock?umask=0007";
            endpoints.authz.auth-request.implementation = "AuthRequest";
          };
          log = {
            level = "info";
            format = "text";
          };
          # password-only authentication: every 2FA method is off so access_control
          # policies can only ever resolve to one_factor
          totp.disable = true;
          webauthn.disable = true;
          duo_api.disable = true;
          authentication_backend = {
            password_reset.disable = true;
            password_change.disable = true;
            file.path = config.nixos.system.sops.templates."authelia/users.yml".path;
          };
          access_control.default_policy = "deny";
          # redis-backed session provider so sessions survive restarts and are
          # shared across Authelia workers
          session = {
            redis = {
              host = "127.0.0.1";
              port = 6382;
            };
            cookies = [
              {
                name = "authelia_session";
                domain = "chn.moe";
                authelia_url = "https://auth.chn.moe";
                default_redirection_url = "https://aidesk.chn.moe";
                same_site = "lax";
                inactivity = "1M";
                expiration = "3M";
                remember_me = "1y";
              }
            ];
          };
          regulation = {
            max_retries = 5;
            find_time = "2m";
            ban_time = "5m";
          };
          storage.postgres = {
            address = "tcp://127.0.0.1:5432";
            database = "authelia";
            username = "authelia";
          };
          # Authelia insists on exactly one notification provider; the filesystem one
          # writes into StateDirectory and needs no SMTP server or credentials
          notifier.filesystem.filename = "/var/lib/authelia-main/notification.txt";
        };
      };
      systemd.services.authelia-main = {
        after = [
          "postgresql.service"
          "redis-authelia.service"
        ];
        requires = [
          "postgresql.service"
          "redis-authelia.service"
        ];
        serviceConfig = {
          # ProtectSystem=strict makes /run read-only, so the socket directory must be declared
          RuntimeDirectory = "authelia-main";
          RuntimeDirectoryMode = "0750";
        };
        restartTriggers = [ config.nixos.system.sops.templates."authelia/users.yml".content ];
      };
      users.users.${config.services.nginx.user}.extraGroups = [
        config.services.authelia.instances.main.group
      ];
      nixos = {
        services = {
          postgresql.instances.authelia = { };
          redis.instances.authelia = {
            user = config.services.authelia.instances.main.user;
            port = 6382;
          };
          nginx.https."auth.chn.moe".location."/".proxy.upstream =
            "http://unix:/run/authelia-main/authelia.sock:";
        };
        system.sops = {
          secrets = lib.mkMerge [
            (
              [
                "jwt-secret"
                "session-secret"
                "storage-encryption-key"
                "oidc-hmac-secret"
                "oidc-issuer-private-key"
                "db"
              ]
              |> lib.flip lib.genAttrs' (
                n:
                lib.nameValuePair "authelia/${n}" {
                  owner = config.services.authelia.instances.main.user;
                }
              )
            )
            (authelia.users |> lib.flip lib.genAttrs' (n: lib.nameValuePair "authelia/users/${n}" { }))
            (
              authelia.clients
              |> lib.flip lib.genAttrs' (n: lib.nameValuePair "authelia/clients/${n.clientId}" { })
            )
            { "authelia/db".key = "postgresql/authelia"; }
          ];
          templates = {
            "authelia/users.yml" = {
              owner = config.services.authelia.instances.main.user;
              content = builtins.toJSON {
                users =
                  authelia.users
                  |> lib.flip lib.genAttrs (n: {
                    displayname = n;
                    password = config.nixos.system.sops.placeholder."authelia/users/${n}";
                    email = "${n}@chn.moe";
                  });
              };
            };
            "authelia/oidc-clients.yml" = {
              owner = config.services.authelia.instances.main.user;
              content = builtins.toJSON {
                identity_providers.oidc.clients =
                  authelia.clients
                  |> lib.map (c: {
                    client_id = c.clientId;
                    client_name = c.clientName;
                    client_secret = config.nixos.system.sops.placeholder."authelia/clients/${c.clientId}";
                    authorization_policy = "one_factor";
                    redirect_uris = c.redirectUris;
                    scopes = [
                      "openid"
                      "email"
                      "profile"
                      "groups"
                    ];
                  });
              };
            };
          };
        };
      };
    };
}
