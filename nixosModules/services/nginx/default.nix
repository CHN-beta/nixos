{
  localLib,
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = localLib.findModules ./.;
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
          package =
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
            pkgs.nginxMainline
            |> (
              p:
              p.override (prev: {
                modules = prev.modules ++ [ nginx-geoip2 ];
              })
            )
            |> (
              p:
              p.overrideAttrs (prev: {
                buildInputs = prev.buildInputs ++ [ pkgs.libmaxminddb ];
              })
            );
          streamConfig = ''
            geoip2 ${config.services.geoipupdate.settings.DatabaseDirectory}/GeoLite2-Country.mmdb {
              $geoip2_data_country_code country iso_code;
            }
            resolver 8.8.8.8;
          '';
          # anyway to use host dns?
          resolver.addresses = [ "8.8.8.8" ];
        };
        networking.firewall.allowedTCPPorts = [
          80
          443
        ];
        nixos.services.geoipupdate = { };
        systemd.services.nginx.serviceConfig = {
          CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];
          AmbientCapabilities = [ "CAP_NET_ADMIN" ];
          LimitNPROC = 65536;
          LimitNOFILE = 524288;
        };
      };
}
