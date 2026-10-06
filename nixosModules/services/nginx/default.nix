{
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = lib.findModules ./.;
  options.nixos.services.nginx = {
    # transparentProxy -> https(with proxyProtocol) or transparentProxy -> streamProxy -> https(with proxyProtocol)
    # https without proxyProtocol listen on private ip, with proxyProtocol listen on all ip
    # streamProxy listen on private ip
    # transparentProxy listen on public ip
    global = lib.mkOption {
      type = lib.types.anything;
      readOnly = true;
      default = {
        httpsPort = 3065;
        httpsPortShift = {
          http2 = 1;
          proxyProtocol = 2;
        };
        httpsLocationTypes = [
          "proxy"
          "static"
          "php"
          "return"
        ];
        httpTypes = [
          "rewriteHttps"
          "php"
          "proxy"
        ];
        streamPort = 5575;
        streamPortShift.proxyProtocol = 1;
      };
    };
  };
  config =
    let
      inherit (config.nixos.services) nginx;
    in
    lib.mkIf
      (
        nginx.http != { }
        || nginx.https != { }
        || nginx.streamProxy.map != { }
        || nginx.transparentProxy.map != { }
      )
      {
        services.nginx = {
          enable = true;
          enableReload = true;
          eventsConfig = ''
            worker_connections 524288;
            use epoll;
          '';
          commonHttpConfig = ''
            vhost_traffic_status_zone;
            vhost_traffic_status_filter_by_host on;
            geoip2 ${config.services.geoipupdate.settings.DatabaseDirectory}/GeoLite2-Country.mmdb {
              $geoip2_data_country_code country iso_code;
            }
            log_format http '[$time_local] $remote_addr-$geoip2_data_country_code "$host"'
              ' $request_length $bytes_sent $status "$request" referer: "$http_referer" ua: "$http_user_agent"'
              ' proxy_pass: "$upstream_addr"';
            access_log syslog:server=unix:/dev/log http;
            proxy_ssl_server_name on;
            proxy_ssl_session_reuse off;
            send_timeout 1d;
            # nginx will try to redirect https://blog.chn.moe/docs to https://blog.chn.moe:3068/docs/ in default
            # this make it redirect to /docs/ without hostname
            absolute_redirect off;
            # allow realip module to set ip
            set_real_ip_from 0.0.0.0/0;
            set_real_ip_from ::/0;
            real_ip_header proxy_protocol;
            # gitea needs long time to upload/download large files over ssh
            client_body_timeout 1h;
          '';
          proxyTimeout = "1d";
          recommendedTlsSettings = true;
          # do not set Host header
          recommendedProxySettings = false;
          recommendedProxySettingsNoHost = true;
          recommendedOptimisation = true;
          recommendedGzipSettings = true;
          recommendedBrotliSettings = true;
          clientMaxBodySize = "0";
          package = pkgs.nginxMainline.overrideAttrs (prev: {
            buildInputs = prev.buildInputs ++ [ pkgs.libmaxminddb ];
          });
          additionalModules =
            let
              nginx-geoip2 = {
                name = "ngx_http_geoip2_module";
                src = pkgs.fetchFromGitHub {
                  owner = "leev";
                  repo = "ngx_http_geoip2_module";
                  rev = "a607a41a8115fecfc05b5c283c81532a3d605425";
                  hash = "sha256-CkmaeEa1iEAabJEDu3FhBUR7QF38koGYlyx+pyKZV9Y=";
                };
                meta.license = [ ];
              };
            in
            [
              nginx-geoip2
              pkgs.nginxModules.vts
              pkgs.nginxModules.pam
            ];
          streamConfig = ''
            geoip2 ${config.services.geoipupdate.settings.DatabaseDirectory}/GeoLite2-Country.mmdb {
              $geoip2_data_country_code country iso_code;
            }
            resolver 8.8.8.8;
          '';
          # anyway to use host dns?
          resolver.addresses = [ "8.8.8.8" ];
          virtualHosts."vts-metrics" = {
            listen = [
              {
                addr = "0.0.0.0";
                port = 9113;
              }
              {
                addr = "[::]";
                port = 9113;
              }
            ];
            locations."/metrics".extraConfig = ''
              vhost_traffic_status_display;
              vhost_traffic_status_display_format prometheus;
            '';
          };
        };
        networking.firewall.allowedTCPPorts = [
          80
          443
          9113
        ];
        nixos.services.geoipupdate = { };
        systemd.services.nginx.serviceConfig = {
          CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];
          AmbientCapabilities = [ "CAP_NET_ADMIN" ];
          LimitNPROC = 65536;
          LimitNOFILE = 524288;
          # Denied syscalls fail with EPERM instead of the default SIGSYS, so a blocked
          # call becomes a diagnosable error instead of a coredump of the worker.
          SystemCallErrorNumber = "EPERM";
          # nixpkgs additionally denies "@privileged @setuid", which also covers setuid,
          # setgid and setgroups. Those must stay allowed: pam_unix's unix_chkpwd helper
          # re-drops to its own uid/gid (setgid(getgid()) / setuid(getuid())) before
          # verifying, and with the syscalls blocked it aborts with PAM_AUTH_ERR without
          # writing anything, showing up only as "read unix_chkpwd output error 0".
          # Needed by nixos.services.omp-web (nginx auth_pam).
          # Cheap concession: this unit holds no CAP_SETUID/CAP_SETGID/CAP_SYS_ADMIN and
          # sets NoNewPrivileges, so those syscalls can only no-op or drop privileges.
          SystemCallFilter = lib.mkForce [ "~@cpu-emulation @debug @keyring @mount @obsolete" ];
        };
      };
}
