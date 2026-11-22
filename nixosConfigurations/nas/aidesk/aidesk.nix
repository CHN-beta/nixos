{
  config,
  lib,
  pkgs,
  ...
}:
let
  users = [
    "straycat"
    "wyh"
    "lcl"
    "mhy"
    "rdhx"
    "yzt"
    "grassblock"
  ];
in
{
  nixos = {
    user.users = users;
    packages.omp.users = users;
    services = {
      cliproxyapi.users = users;
      authelia = {
        inherit users;
        clients = [
          {
            clientId = "gitea";
            clientName = "Gitea";
            redirectUris = [ "https://gitea.chn.moe/user/oauth2/authelia/callback" ];
          }
        ];
      };
      nginx.https = lib.genAttrs [ "api.aidesk.chn.moe" "api2.aidesk.chn.moe" ] (
        host:
        lib.recursiveUpdate
          {
            global.extraConfig = ''
              # terminal streams and server-sent events must not be buffered
              proxy_buffering off;
              proxy_cache off;
              gzip off;

              # The SPA runs on another origin and calls this API with the Authelia
              # cookie. "always" also covers 401/403/5xx: without it the browser turns
              # those into opaque CORS failures and fetch() cannot see the 401.
              add_header Access-Control-Allow-Origin "https://aidesk.chn.moe" always;
              add_header Access-Control-Allow-Credentials "true" always;
              add_header Access-Control-Allow-Methods "GET, POST, PUT, PATCH, DELETE, OPTIONS" always;
              add_header Access-Control-Allow-Headers "Content-Type, Authorization, Accept, Cache-Control, Last-Event-ID, If-None-Match, Range" always;
              # fetch() can only read these when they are exposed: X-File-Mtime
              # drives the editor's save conflict detection, ETag/If-None-Match the
              # session list, and the length/range pair seeks in media previews.
              add_header Access-Control-Expose-Headers "X-File-Mtime, ETag, Content-Length, Content-Range" always;

              # A CORS preflight carries no cookie, but it must still succeed. "if" in
              # server context runs in the rewrite phase, before auth_request in the
              # access phase, so the browser gets 204 here and only the real request
              # that follows is answered with 401.
              if ($request_method = OPTIONS) {
                return 204;
              }

              # Authelia guards the whole site and tells us which user is logged in
              auth_request /internal/authelia/authz;
              auth_request_set $authelia_user $upstream_http_remote_user;
              auth_request_set $authelia_groups $upstream_http_remote_groups;
              auth_request_set $authelia_name $upstream_http_remote_name;
              auth_request_set $authelia_email $upstream_http_remote_email;
              # no error_page 401 =302: fetch() must observe the real 401 and send the
              # top-level window to Authelia itself, with "rd" pointing back here
            '';
            location = {
              # proxy_pass runs with variables, so the original request URI is forwarded
              "/api/".proxy.upstream = "http://unix:/run/aidesk-$authelia_user/aidesk.sock:";
              "= /api/model-catalog.json".static.root =
                let
                  modelCatalog = pkgs.writeTextDir "api/model-catalog.json" (
                    builtins.toJSON {
                      vendors = {
                        google = {
                          en = "Google";
                          zh-CN = "Google";
                          order = 1;
                        };
                        deepseek = {
                          en = "DeepSeek";
                          zh-CN = "深度求索";
                          order = 2;
                        };
                        openai = {
                          en = "OpenAI";
                          zh-CN = "OpenAI";
                          order = 3;
                        };
                        anthropic = {
                          en = "Anthropic";
                          zh-CN = "Anthropic";
                          order = 4;
                        };
                        bytedance = {
                          en = "ByteDance";
                          zh-CN = "字节跳动";
                          order = 5;
                        };
                        zhipu = {
                          en = "Zhipu AI";
                          zh-CN = "智谱";
                          order = 6;
                        };
                        alibaba = {
                          en = "Alibaba Qwen";
                          zh-CN = "阿里通义千问";
                          order = 7;
                        };
                        moonshot = {
                          en = "Moonshot AI";
                          zh-CN = "月之暗面";
                          order = 8;
                        };
                        minimax = {
                          en = "MiniMax";
                          zh-CN = "MiniMax";
                          order = 9;
                        };
                        tencent = {
                          en = "Tencent Hunyuan";
                          zh-CN = "腾讯混元";
                          order = 10;
                        };
                        xai = {
                          en = "xAI";
                          zh-CN = "xAI";
                          order = 11;
                        };
                        meta = {
                          en = "Meta";
                          zh-CN = "Meta";
                          order = 12;
                        };
                        mistral = {
                          en = "Mistral AI";
                          zh-CN = "Mistral AI";
                          order = 13;
                        };
                      };
                      models = lib.listToAttrs (
                        lib.imap0 (
                          order: pricing: lib.nameValuePair "cliproxyapi/${pricing.model}" (pricing // { inherit order; })
                        ) (import ./data/model-pricing.nix)
                      );
                    }
                  );
                in
                "${modelCatalog}";
            };
          }
          (
            lib.optionalAttrs (host == "api2.aidesk.chn.moe") {
              # The HTTPS wrapper's listeners use shared internal proxy ports.
              listen = { };
              global.rewriteHttps = false;
            }
          )
      );
    };
  };
  users.users = lib.genAttrs users (user: {
    hashedPassword = lib.mkDefault "*";
  });
  security.pam.services.sshd.rules.auth.aidesk-authelia = {
    order = config.security.pam.services.sshd.rules.auth.unix.order - 10;
    control = "sufficient";
    modulePath = "${config.security.pam.package}/lib/security/pam_exec.so";
    args =
      let
        pamAuthelia = pkgs.writeShellApplication {
          name = "pam-authelia";
          # a pure PATH: pam_exec's environment comes from sshd, and a helper that
          # decides about logins must not depend on (or trust) it
          inheritPath = false;
          runtimeInputs = [
            pkgs.coreutils
            pkgs.curl
          ];
          meta.mainProgram = "pam-authelia";
          text = ''
            # only the AIDesk accounts may ever pass this PAM rule
            case "''${PAM_USER:-}" in
              ${lib.concatStringsSep "|" users}) ;;
              *) exit 1 ;;
            esac

            # pam_exec writes the authtok to stdin and closes the pipe; passwords
            # cannot contain the newline that command substitution would strip
            password=$(cat)
            [ -n "$password" ] || exit 1

            credentials=$(printf '%s:%s' "$PAM_USER" "$password" | base64 -w0)

            # The auth-request implementation authorizes the X-Original-URL against
            # access_control (i.e. the rule below), and its default authentication
            # strategies read Basic credentials from Authorization, falling back to
            # the session cookie the browser path uses. Only an explicit 200 allows
            # the login: a 3xx portal redirect must not count.
            status=$(curl \
              --silent --show-error \
              --connect-timeout 3 --max-time 10 \
              --proxy "" \
              --unix-socket /run/authelia-main/authelia.sock \
              --config <(printf 'header = "Authorization: Basic %s"\n' "$credentials") \
              --header "X-Original-Method: GET" \
              --header "X-Original-URL: https://api.aidesk.chn.moe/" \
              --output /dev/null --write-out '%{http_code}' \
              "http://localhost/api/authz/auth-request") || exit 1

            [ "$status" = "200" ]
          '';
        };
      in
      [
        "expose_authtok"
        "quiet"
        (lib.getExe pamAuthelia)
      ];
  };
  services = {
    authelia.instances.main.settings.access_control.rules = [
      {
        domain = [
          "api.aidesk.chn.moe"
          "api2.aidesk.chn.moe"
        ];
        policy = "one_factor";
        subject = builtins.map (user: "user:${user}") users;
      }
    ];
    # PasswordAuthentication is off globally on nas; re-enable it in a Match
    # block (which sshd puts at the end of sshd_config) for the AIDesk users
    openssh.extraConfig = ''
      Match User ${lib.concatStringsSep "," users}
        PasswordAuthentication yes
    '';
    nginx.virtualHosts = lib.genAttrs [ "https:api.aidesk.chn.moe" "https:api2.aidesk.chn.moe" ] (
      vhost:
      {
        locations = {
          "/login/".extraConfig = ''
            auth_request off;
            # Replace the /login/ prefix with / before passing the URI to Authelia.
            proxy_pass http://unix:/run/authelia-main/authelia.sock:/;
            proxy_set_header Host $server_name;
            proxy_set_header X-Forwarded-Host $server_name;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-For $remote_addr;
          '';
          "/api/".extraConfig = ''
            proxy_set_header Remote-User $authelia_user;
            proxy_set_header Remote-Groups $authelia_groups;
            proxy_set_header Remote-Name $authelia_name;
            proxy_set_header Remote-Email $authelia_email;
          '';
          "= /api/model-catalog.json".extraConfig = ''
            default_type application/json;
            auth_request off;
          '';
          # server level auth_request is inherited by every location, including this
          # one; without "auth_request off" the subrequest would authenticate itself
          "= /internal/authelia/authz".extraConfig = ''
            internal;
            auth_request off;
            proxy_pass http://unix:/run/authelia-main/authelia.sock:/api/authz/auth-request;
            proxy_set_header X-Original-Method $request_method;
            proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
            proxy_set_header X-Forwarded-For $remote_addr;
            proxy_set_header Content-Length "";
            proxy_set_header Connection "";
            proxy_pass_request_body off;
          '';
        };
      }
      // lib.optionalAttrs (vhost == "https:api2.aidesk.chn.moe") {
        listen =
          map
            (addr: {
              inherit addr;
              port = 8443;
              ssl = true;
              extraParameters = [ "http2" ];
            })
            [
              "0.0.0.0"
              "[::]"
            ];
        quic = true;
        http3 = true;
      }
    );
  };
  # PAM/logind places SSH sessions in the corresponding per-user slice.
  systemd.slices = lib.genAttrs' users (
    user:
    lib.nameValuePair "user-${toString config.users.users.${user}.uid}" {
      sliceConfig = {
        DevicePolicy = "closed";
        DeviceAllow = [
          "char-pts rw"
          "/dev/fuse rw"
        ];
      };
    }
  );
  networking.firewall = {
    allowedTCPPorts = [ 8443 ];
    allowedUDPPorts = [ 8443 ];
  };
  networking.nftables.tables.aidesk-loopback-filter = {
    family = "inet";
    content = ''
      chain output {
        # Check the original route before Xray can reroute public traffic to lo.
        type filter hook output priority mangle - 1; policy accept;
        meta skuid { ${
          lib.concatMapStringsSep ", " (user: toString config.users.users.${user}.uid) users
        } } jump user_egress
      }
      chain output_after_dnat {
        # Check again after local port forwards can rewrite the destination.
        type filter hook output priority filter; policy accept;
        ct status dnat meta skuid { ${
          lib.concatMapStringsSep ", " (user: toString config.users.users.${user}.uid) users
        } } jump user_egress
      }
      chain user_egress {
        ct state established,related accept
        oifname "lo" jump local_allowlist
        fib daddr type local jump local_allowlist
        oifname { "tailscale*", "tinc*" } reject with icmpx type admin-prohibited
        ip daddr { 10.0.0.0/8, 100.64.0.0/10, 169.254.0.0/16, 172.16.0.0/12, 192.168.0.0/16 } reject with icmpx type admin-prohibited
        ip6 daddr { fc00::/7, fe80::/10 } reject with icmpx type admin-prohibited
      }
      chain local_allowlist {
        # The host uses CoreDNS on 127.0.0.1; no LAN DNS exception is needed.
        udp dport { 53, 8443, 32768-60999 } accept
        tcp dport { 22, 53, 80, 443, 3000, 4173, 5173, 8443, 8788, 32768-60999 } accept
        reject with icmpx type admin-prohibited
      }
    '';
  };
  systemd.services =
    let
      mkService = user: {
        description = "AIDesk backend for ${user}";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        environment = {
          HOME = "/home/${user}";
          PATH = "/etc/profiles/per-user/${user}/bin:/run/current-system/sw/bin";
          AIDESK_OMP_BIN = "/etc/profiles/per-user/${user}/bin/omp";
          PI_CODING_AGENT_DIR = "/home/${user}/.omp/agent";
        };
        serviceConfig = {
          Type = "simple";
          User = user;
          # the backend chmods its socket to 0660, so both the socket and the
          # RuntimeDirectory (0750) belong to the nginx group and only nginx can
          # connect; the service keeps the user's own uid for everything else
          Group = config.services.nginx.group;
          WorkingDirectory = "/home/${user}";
          ExecStart = "${pkgs.localPkgs.aidesk.backend}/bin/aidesk-backend --socket /run/aidesk-${user}/aidesk.sock";
          RuntimeDirectory = "aidesk-${user}";
          RuntimeDirectoryMode = "0750";
          # PrivateDevices still provides the PTYs used by the web terminal.
          PrivateDevices = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectKernelLogs = true;
          ProtectControlGroups = true;
          ProtectProc = "invisible";
          NoNewPrivileges = true;
          RestrictSUIDSGID = true;
          Restart = "on-failure";
          RestartSec = 5;
          # The backend shuts down by closing the stdin of its omp children and
          # waiting for them to flush and exit on their own. The default
          # "control-group" would SIGTERM those children at the same instant as
          # the backend, so it could neither wait for them nor tell whether they
          # finished. "mixed" signals only ExecStart, and whatever is still in the
          # cgroup after TimeoutStopSec is then killed, so nothing is orphaned.
          KillMode = "mixed";
          TimeoutStopSec = 15;
        };
        enableDefaultPath = false;
      };
    in
    lib.genAttrs' users (user: lib.nameValuePair "aidesk-${user}" (mkService user))
    // {
      aidesk-stt = {
        description = "AIDesk speech transcription and editing";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "simple";
          DynamicUser = true;
          ExecStart = "${lib.getExe pkgs.localPkgs.aidesk.stt} --api-key-file %d/siliconflow";
          LoadCredential = "siliconflow:${config.nixos.system.sops.secrets."hindsight/siliconflow".path}";
          PrivateDevices = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectKernelLogs = true;
          ProtectControlGroups = true;
          ProtectProc = "invisible";
          NoNewPrivileges = true;
          RestrictSUIDSGID = true;
          Restart = "on-failure";
          RestartSec = 5;
        };
      };
    };
}
