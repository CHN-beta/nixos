{ config, lib, ... }:
let
  autheliaUser = config.services.authelia.instances.main.user;

  # the first matching rule wins, so more specific resources must come before broader ones
  sortLocations = lib.sort (a: b: builtins.stringLength a.locName > builtins.stringLength b.locName);

  mkSiteRules =
    siteName: site:
    let
      globalAuthelia = site.global.authelia;
      locations =
        lib.mapAttrsToList (
          locName: location:
          let
            selected = builtins.head (builtins.filter (type: type.value != null) (lib.attrsToList location));
          in
          {
            inherit locName;
            authelia = selected.value.authelia or null;
          }
        ) site.location
        |> builtins.filter (location: location.authelia != null || globalAuthelia != null)
        |> sortLocations;
      mkLocationRules =
        location:
        let
          users = if location.authelia != null then location.authelia.users else globalAuthelia.users;
          resources = lib.optional (
            location.locName != "/"
          ) "^${lib.strings.escapeRegex location.locName}(/.*)?$";
          rule = {
            domain = siteName;
          }
          // lib.optionalAttrs (resources != [ ]) { inherit resources; };
        in
        if users == null then
          [ (rule // { policy = "one_factor"; }) ]
        else
          [
            (
              rule
              // {
                policy = "one_factor";
                subject = map (user: "user:${user}") users;
              }
            )
            (rule // { policy = "deny"; })
          ];
    in
    builtins.concatMap mkLocationRules locations;

  accessControlRules =
    builtins.concatLists (lib.mapAttrsToList mkSiteRules config.nixos.services.nginx.https)
    ++ [
      {
        domain = "*.chn.moe";
        policy = "one_factor";
      }
    ];
in
{
  config = {
    services.authelia.instances.main = {
      enable = true;
      secrets = {
        jwtSecretFile = config.nixos.system.sops.secrets."authelia/jwt-secret".path;
        sessionSecretFile = config.nixos.system.sops.secrets."authelia/session-secret".path;
        storageEncryptionKeyFile = config.nixos.system.sops.secrets."authelia/storage-encryption-key".path;
        oidcHmacSecretFile = config.nixos.system.sops.secrets."authelia/oidc-hmac-secret".path;
        oidcIssuerPrivateKeyFile = config.nixos.system.sops.secrets."authelia/oidc-issuer-private-key".path;
      };
      environmentVariables = {
        AUTHELIA_SESSION_REDIS_PASSWORD_FILE = config.nixos.system.sops.secrets."redis/authelia".path;
        AUTHELIA_STORAGE_POSTGRES_PASSWORD_FILE = config.nixos.system.sops.secrets."authelia/db".path;
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
          file = {
            path = config.nixos.system.sops.templates."authelia/users.yml".path;
            watch = true;
          };
        };
        access_control = {
          default_policy = "deny";
          rules = accessControlRules;
        };
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
              default_redirection_url = "https://desk.chn.moe";
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
    };
    users.users.${config.services.nginx.user}.extraGroups = [
      config.services.authelia.instances.main.group
    ];
    nixos = {
      services = {
        postgresql.instances.authelia = { };
        redis.instances.authelia = {
          user = autheliaUser;
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
                owner = autheliaUser;
              }
            )
          )
          (
            [
              "gitea-client-secret-hash"
              "users/straycat"
              "users/wyh"
              "users/lcl"
            ]
            |> lib.flip lib.genAttrs' (n: lib.nameValuePair "authelia/${n}" { })
          )
          { "authelia/db".key = "postgresql/authelia"; }
        ];
        templates = {
          "authelia/users.yml" = {
            owner = autheliaUser;
            content = builtins.toJSON {
              users =
                [
                  "straycat"
                  "wyh"
                  "lcl"
                ]
                |> lib.flip lib.genAttrs (n: {
                  displayname = n;
                  password = config.nixos.system.sops.placeholder."authelia/users/${n}";
                  email = "${n}@chn.moe";
                });
            };
          };
          "authelia/oidc-clients.yml" = {
            owner = autheliaUser;
            content = builtins.toJSON {
              identity_providers.oidc.clients = [
                {
                  client_id = "gitea";
                  client_name = "Gitea";
                  client_secret = config.nixos.system.sops.placeholder."authelia/gitea-client-secret-hash";
                  authorization_policy = "one_factor";
                  redirect_uris = [ "https://git.chn.moe/user/oauth2/authelia/callback" ];
                  scopes = [
                    "openid"
                    "email"
                    "profile"
                    "groups"
                  ];
                }
              ];
            };
          };
        };
      };
    };
  };
}
