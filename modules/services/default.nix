inputs:
{
  imports = inputs.localLib.mkModules
  [
    ./postgresql.nix
    ./redis.nix
    ./rsshub.nix
    ./misskey.nix
    ./nginx.nix
    ./meilisearch.nix
    ./xray.nix
    ./coturn.nix
    ./synapse.nix
    ./nebula
    # ./docker.nix
  ];
  options.nixos.services = let inherit (inputs.lib) mkOption types; in
  {
    impermanence =
    {
      enable = mkOption { type = types.bool; default = false; };
      persistence = mkOption { type = types.nonEmptyStr; default = "/nix/persistent"; };
      root = mkOption { type = types.nonEmptyStr; default = "/nix/rootfs/current"; };
      nodatacow = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
    };
    snapper =
    {
      enable = mkOption { type = types.bool; default = false; };
      configs = mkOption { type = types.attrsOf types.nonEmptyStr; default = {}; };
    };
    kmscon.enable = mkOption { type = types.bool; default = false; };
    fontconfig.enable = mkOption { type = types.bool; default = false; };
    sops =
    {
      enable = mkOption { type = types.bool; default = false; };
      keyPathPrefix = mkOption { type = types.str; default = ""; };
    };
    samba =
    {
      enable = mkOption { type = types.bool; default = false; };
      wsdd = mkOption { type = types.bool; default = false; };
      private = mkOption { type = types.bool; default = false; };
      hostsAllowed = mkOption { type = types.str; default = "127."; };
      shares = mkOption
      {
        type = types.attrsOf (types.submodule { options =
        {
          comment = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
          path = mkOption { type = types.nonEmptyStr; };
        };});
        default = {};
      };
    };
    sshd.enable = mkOption { type = types.bool; default = false; };
    firewall.trustedInterfaces = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
    acme =
    {
      enable = mkOption { type = types.bool; default = false; };
      certs = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
    };
    frpClient =
    {
      enable = mkOption { type = types.bool; default = false; };
      serverName = mkOption { type = types.nonEmptyStr; };
      user = mkOption { type = types.nonEmptyStr; };
      tcp = mkOption
      {
        type = types.attrsOf (types.submodule (inputs:
        {
          options =
          {
            localIp = mkOption { type = types.nonEmptyStr; default = "127.0.0.1"; };
            localPort = mkOption { type = types.ints.unsigned; };
            remoteIp = mkOption { type = types.nonEmptyStr; default = "127.0.0.1"; };
            remotePort = mkOption { type = types.ints.unsigned; default = inputs.config.localPort; };
          };
        }));
        default = {};
      };
    };
    frpServer =
    {
      enable = mkOption { type = types.bool; default = false; };
      serverName = mkOption { type = types.nonEmptyStr; };
    };
    nix-serve =
    {
      enable = mkOption { type = types.bool; default = false; };
      hostname = mkOption { type = types.nonEmptyStr; };
    };
    smartd.enable = mkOption { type = types.bool; default = false; };
    fileshelter.enable = mkOption { type = types.bool; default = false; };
    wallabag.enable = mkOption { type = types.bool; default = false; };
  };
  config =
    let
      inherit (inputs.lib) mkMerge mkIf;
      inherit (inputs.localLib) stripeTabs attrsToList;
      inherit (inputs.config.nixos) services;
      inherit (builtins) map listToAttrs toString;
    in mkMerge
    [
      (
        mkIf services.impermanence.enable
        {
          environment.persistence =
          {
            "${services.impermanence.persistence}" =
            {
              hideMounts = true;
              directories =
              [
                "/etc/NetworkManager/system-connections"
                "/home"
                "/root"
                "/var/db"
                "/var/lib"
                "/var/log"
                "/var/spool"
              ];
              files =
              [
                "/etc/machine-id"
                "/etc/ssh/ssh_host_ed25519_key.pub"
                "/etc/ssh/ssh_host_ed25519_key"
                "/etc/ssh/ssh_host_rsa_key.pub"
                "/etc/ssh/ssh_host_rsa_key"
              ];
            };
            "${services.impermanence.root}" =
            {
              hideMounts = true;
              directories = []
                ++ (if inputs.config.services.xserver.displayManager.sddm.enable then
                  [{ directory = "/var/lib/sddm"; user = "sddm"; group = "sddm"; mode = "0700"; }] else []);
            };
          }
          // (
            if (services.impermanence.nodatacow != null) then
            {
              "${services.impermanence.nodatacow}" =
              {
                hideMounts = true;
                directories =
                [
                  "/var/lib/postgresql"
                  "/var/lib/meilisearch"
                ];
              };
            }
            else {}
          );
        }
      )
      (
        mkIf services.snapper.enable
        {
          services.snapper.configs =
            let
              f = (config:
              {
                inherit (config) name;
                value =
                {
                  SUBVOLUME = config.value;
                  TIMELINE_CREATE = true;
                  TIMELINE_CLEANUP = true;
                  TIMELINE_MIN_AGE = 1800;
                  TIMELINE_LIMIT_HOURLY = "10";
                  TIMELINE_LIMIT_DAILY = "7";
                  TIMELINE_LIMIT_WEEKLY = "1";
                  TIMELINE_LIMIT_MONTHLY = "0";
                  TIMELINE_LIMIT_YEARLY = "0";
                };
              });
            in
              listToAttrs (map f (attrsToList services.snapper.configs));
          nixpkgs.config.packageOverrides = pkgs: 
          {
            snapper = pkgs.snapper.overrideAttrs (attrs:
            {
              patches = (if (attrs ? patches) then attrs.patches else []) ++ [ ./snapper.patch ];
            });
          };
        }
      )
      (
        mkIf services.kmscon.enable
        {
          services.kmscon =
          {
            enable = true;
            fonts = [{ name = "FiraCode Nerd Font Mono"; package = inputs.pkgs.nerdfonts; }];
          };
        }
      )
      (
        mkIf services.fontconfig.enable
        {
          fonts =
          {
            fontDir.enable = true;
            packages = with inputs.pkgs;
              [ noto-fonts source-han-sans source-han-serif source-code-pro hack-font jetbrains-mono nerdfonts ];
            fontconfig.defaultFonts =
            {
              emoji = [ "Noto Color Emoji" ];
              monospace = [ "Noto Sans Mono CJK SC" "Sarasa Mono SC" "DejaVu Sans Mono"];
              sansSerif = [ "Noto Sans CJK SC" "Source Han Sans SC" "DejaVu Sans" ];
              serif = [ "Noto Serif CJK SC" "Source Han Serif SC" "DejaVu Serif" ];
            };
          };
        }
      )
      (
        mkIf services.sops.enable
        {
          sops =
          {
            defaultSopsFile = ../../secrets/${inputs.config.networking.hostName}.yaml;
            # sops start before impermanence, so we need to use the absolute path
            age.sshKeyPaths = [ "${services.sops.keyPathPrefix}/etc/ssh/ssh_host_ed25519_key" ];
            gnupg.sshKeyPaths = [ "${services.sops.keyPathPrefix}/etc/ssh/ssh_host_rsa_key" ];
          };
        }
      )
      (
        mkIf services.samba.enable
        {
          # make shares visible for windows 10 clients
          services =
          {
            samba-wsdd.enable = services.samba.wsdd;
            samba =
            {
              enable = true;
              openFirewall = !services.samba.private;
              securityType = "user";
              extraConfig =
              ''
                workgroup = WORKGROUP
                server string = Samba Server
                server role = standalone server
                hosts allow = ${services.samba.hostsAllowed}
                dns proxy = no
              '';
              #  obey pam restrictions = yes
              #  encrypt passwords = no
              shares = listToAttrs (map
                (share:
                {
                  name = share.name;
                  value =
                  {
                    comment = if share.value.comment != null then share.value.comment else share.name;
                    path = share.value.path;
                    browseable = true;
                    writeable = true;
                    "create mask" = "664";
                    "force create mode" = "644";
                    "directory mask" = "2755";
                    "force directory mode" = "2755";
                  };
                })
                (attrsToList services.samba.shares));
            };
          };
        }
      )
      (
        mkIf services.sshd.enable
        {
          services.openssh =
          {
            enable = true;
            settings =
            {
              X11Forwarding = true;
              TrustedUserCAKeys = builtins.toString ./ca.pub;
              ChallengeResponseAuthentication = false;
              PasswordAuthentication = false;
              KbdInteractiveAuthentication = false;
              UsePAM = true;
            };
          };
        }
      )
      { networking.firewall.trustedInterfaces = services.firewall.trustedInterfaces; }
      (
        mkIf services.acme.enable
        {
          security.acme =
          {
            acceptTerms = true;
            defaults.email = "chn@chn.moe";
            certs = listToAttrs (map
              (name:
              {
                name = name; value =
                {
                  dnsResolver = "8.8.8.8";
                  dnsProvider = "cloudflare";
                  credentialsFile = inputs.config.sops.secrets."acme/cloudflare.ini".path;
                };
              })
              services.acme.certs);
          };
          sops.secrets."acme/cloudflare.ini" = {};
        }
      )
      (
        mkIf (services.frpClient.enable)
        {
          systemd.services.frpc =
            let
              frpc = "${inputs.pkgs.frp}/bin/frpc";
              config = inputs.config.sops.templates."frpc.ini";
            in
            {
              description = "Frp Client Service";
              after = [ "network.target" ];
              serviceConfig =
              {
                Type = "simple";
                User = "frp";
                Restart = "always";
                RestartSec = "5s";
                ExecStart = "${frpc} -c ${config.path}";
                LimitNOFILE = 1048576;
              };
              wantedBy= [ "multi-user.target" ];
              restartTriggers = [ config.file ];
            };
          sops =
          {
            templates."frpc.ini" =
            {
              owner = inputs.config.users.users.frp.name;
              group = inputs.config.users.users.frp.group;
              content = inputs.lib.generators.toINI {}
              (
                {
                  common =
                  {
                    server_addr = services.frpClient.serverName;
                    server_port = 7000;
                    token = inputs.config.sops.placeholder."frp/token";
                    user = services.frpClient.user;
                    tls_enable = true;
                  };
                }
                // (listToAttrs (map
                  (tcp:
                  {
                    name = tcp.name;
                    value =
                    {
                      type = "tcp";
                      local_ip = tcp.value.localIp;
                      local_port = tcp.value.localPort;
                      remote_port = tcp.value.remotePort;
                      use_compression = true;
                    };
                  })
                  (attrsToList services.frpClient.tcp))
                )
              );
            };
            secrets."frp/token" = {};
          };
          users = { users.frp = { isSystemUser = true; group = "frp"; }; groups.frp = {}; };
        }
      )
      (
        mkIf (services.frpServer.enable)
        {
          systemd.services.frps =
            let
              frps = "${inputs.pkgs.frp}/bin/frps";
              config = inputs.config.sops.templates."frps.ini";
            in
            {
              description = "Frp Server Service";
              after = [ "network.target" ];
              serviceConfig =
              {
                Type = "simple";
                User = "frp";
                Restart = "on-failure";
                RestartSec = "5s";
                ExecStart = "${frps} -c ${config.path}";
                LimitNOFILE = 1048576;
              };
              wantedBy= [ "multi-user.target" ];
              restartTriggers = [ config.file ];
            };
          sops =
          {
            templates."frps.ini" =
            {
              owner = inputs.config.users.users.frp.name;
              group = inputs.config.users.users.frp.group;
              content = inputs.lib.generators.toINI {}
              {
                common = let cert = inputs.config.security.acme.certs.${services.frpServer.serverName}.directory; in
                {
                  bind_port = 7000;
                  bind_udp_port = 7000;
                  token = inputs.config.sops.placeholder."frp/token";
                  tls_cert_file = "${cert}/full.pem";
                  tls_key_file = "${cert}/key.pem";
                  tls_only = true;
                  user_conn_timeout = 30;
                };
              };
            };
            secrets."frp/token" = {};
          };
          nixos.services.acme = { enable = true; certs = [ services.frpServer.serverName ]; };
          security.acme.certs.${services.frpServer.serverName}.group = "frp";
          users = { users.frp = { isSystemUser = true; group = "frp"; }; groups.frp = {}; };
          networking.firewall.allowedTCPPorts = [ 7000 ];
        }
      )
      (
        mkIf services.nix-serve.enable
        {
          services.nix-serve =
          {
            enable = true;
            openFirewall = true;
            secretKeyFile = inputs.config.sops.secrets."store/signingKey".path;
          };
          sops.secrets."store/signingKey" = {};
          nixos.services.nginx.httpProxy.${services.nix-serve.hostname}.upstream = "http://127.0.0.1:5000";
        }
      )
      (mkIf services.smartd.enable { services.smartd.enable = true; })
      (
        mkIf services.wallabag.enable
        {
          virtualisation.oci-containers.containers.wallabag =
          {
            image = "wallabag/wallabag:2.6.2";
            imageFile = inputs.pkgs.dockerTools.pullImage
            {
              imageName = "wallabag/wallabag";
              imageDigest = "sha256:241e5c71f674ee3f383f428e8a10525cbd226d04af58a40ce9363ed47e0f1de9";
              sha256 = "0zflrhgg502w3np7kqmxij8v44y491ar2qbk7qw981fysia5ix09";
              finalImageName = "wallabag/wallabag";
              finalImageTag = "2.6.2";
            };
            ports = [ "127.0.0.1:4398:80/tcp" ];
            extraOptions = [ "--add-host=host.docker.internal:host-gateway" ];
            environmentFiles = [ inputs.config.sops.templates."wallabag/env".path ];
          };
          # systemd.services.docker-wallabag.serviceConfig =
          # {
          #   User = "wallabag";
          #   Group = "wallabag";
          # };
          sops =
          {
            templates."wallabag/env".content =
              let
                placeholder = inputs.config.sops.placeholder;
              in
              ''
                SYMFONY__ENV__DATABASE_DRIVER=pdo_pgsql
                SYMFONY__ENV__DATABASE_HOST=host.docker.internal
                SYMFONY__ENV__DATABASE_PORT=5432
                SYMFONY__ENV__DATABASE_NAME=wallabag
                SYMFONY__ENV__DATABASE_USER=wallabag
                SYMFONY__ENV__DATABASE_PASSWORD=${placeholder."postgresql/wallabag"}
                SYMFONY__ENV__REDIS_HOST=host.docker.internal
                SYMFONY__ENV__REDIS_PORT=8790
                SYMFONY__ENV__REDIS_PASSWORD=${placeholder."redis/wallabag"}
                SYMFONY__ENV__SERVER_NAME=wallabag.chn.moe
                SYMFONY__ENV__DOMAIN_NAME=https://wallabag.chn.moe
                SYMFONY__ENV__TWOFACTOR_AUTH=false
              '';
              # SYMFONY__ENV__MAILER_DSN=smtp://bot%%40chn.moe@${placeholder."mail/bot-encoded"}:mail.chn.moe
              # SYMFONY__ENV__FROM_EMAIL=bot@chn.moe
              # SYMFONY__ENV__TWOFACTOR_SENDER=bot@chn.moe
            secrets =
            {
              "redis/wallabag".owner = inputs.config.users.users.redis-wallabag.name;
              "postgresql/wallabag" = {};
              "mail/bot-encoded" = {};
            };
          };
          services =
          {
            redis.servers.wallabag =
            {
              enable = true;
              bind = null;
              port = 8790;
              requirePassFile = inputs.config.sops.secrets."redis/wallabag".path;
            };
            postgresql =
            {
              ensureDatabases = [ "wallabag" ];
              ensureUsers =
              [{
                name = "wallabag";
                ensurePermissions."DATABASE \"wallabag\"" = "ALL PRIVILEGES";
              }];
              # ALTER DATABASE db_name OWNER TO new_owner_name
              # sudo docker exec -t wallabag /var/www/wallabag/bin/console wallabag:install --env=prod --no-interaction
            };
          };
          nixos =
          {
            services =
            {
              nginx =
              {
                enable = true;
                httpProxy."wallabag.chn.moe" =
                {
                  upstream = "http://127.0.0.1:4398";
                  setHeaders.Host = "wallabag.chn.moe";
                };
              };
              postgresql.enable = true;
            };
            virtualization.docker.enable = true;
          };
          # users =
          # {
          #   users.wallabag = { isSystemUser = true; group = "wallabag"; autoSubUidGidRange = true; };
          #   groups.wallabag = {};
          # };
        }
      )
    ];
}
