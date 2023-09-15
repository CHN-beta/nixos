inputs:
{
  options.nixos.services.nginx = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    transparentProxy =
    {
      enable = mkOption { type = types.bool; default = true; };
      externalIp = mkOption { type = types.nonEmptyStr; };
      map = mkOption { type = types.attrsOf types.ints.unsigned; default = {};};
    };
    httpProxy = mkOption
    {
      type = types.attrsOf (types.submodule { options =
      {
        upstream = mkOption { type = types.nonEmptyStr; };
        rewriteHttps = mkOption { type = types.bool; default = false; };
        websocket = mkOption { type = types.bool; default = false; };
        http2 = mkOption { type = types.bool; default = true; };
        setHeaders = mkOption { type = types.attrsOf types.nonEmptyStr; default = {}; };
        addAuth = mkOption { type = types.bool; default = false; };
        detectAuth = mkOption { type = types.bool; default = false; };
      };});
      default = {};
    };
    streamProxy =
    {
      enable = mkOption { type = types.bool; default = false; };
      port = mkOption { type = types.ints.unsigned; default = 5575; };
      map = mkOption
      {
        type = types.attrsOf (types.oneOf
        [
          types.nonEmptyStr
          (types.submodule { options =
          {
            upstream = mkOption { type = types.nonEmptyStr; };
            rewriteHttps = mkOption { type = types.bool; default = false; };
          };})
        ]);
        default = {};
      };
    };
  };
  config =
    let
      inherit (inputs.lib) mkMerge mkIf;
      inherit (inputs.localLib) stripeTabs attrsToList;
      inherit (inputs.config.nixos.services) nginx;
      inherit (builtins) map listToAttrs concatStringsSep toString filter attrValues;
    in mkMerge
    [
      (mkIf nginx.enable
      {
        services =
        {
          nginx =
          {
            enable = true;
            enableReload = true;
            eventsConfig =
            ''
              worker_connections 524288;
              use epoll;
            '';
            commonHttpConfig =
            ''
              geoip2 ${inputs.config.services.geoipupdate.settings.DatabaseDirectory}/GeoLite2-Country.mmdb {
                $geoip2_data_country_code country iso_code;
              }
              log_format http '[$time_local] $remote_addr-$geoip2_data_country_code "$host"'
                ' $request_length $bytes_sent $status "$request" referer: "$http_referer" ua: "$http_user_agent"';
              access_log syslog:server=unix:/dev/log http;
              proxy_ssl_server_name on;
              proxy_ssl_session_reuse off;
              send_timeout 10m;
            '';
            proxyTimeout = "10m";
            virtualHosts = listToAttrs (map
              (site:
              {
                inherit (site) name;
                value =
                {
                  serverName = site.name;
                  listen =
                  [
                    { addr = "127.0.0.1"; port = (if site.value.http2 then 443 else 3065); ssl = true; }
                    { addr = "0.0.0.0"; port = 80; }
                  ];
                  useACMEHost = site.name;
                  locations."/" =
                  {
                    proxyPass = site.value.upstream;
                    proxyWebsockets = site.value.websocket;
                    recommendedProxySettings = false;
                    recommendedProxySettingsNoHost = true;
                    basicAuthFile =
                      if site.value.detectAuth then
                        inputs.config.sops.secrets."nginx/detectAuth/${site.name}".path
                      else null;
                    extraConfig = concatStringsSep "\n"
                    (
                      (map
                        (header: "proxy_set_header ${header.name} ${header.value};")
                        (attrsToList site.value.setHeaders))
                      ++ (if site.value.detectAuth then ["proxy_hide_header Authorization;"] else [])
                      ++ (
                        if site.value.addAuth then
                          ["include ${inputs.config.sops.templates."nginx/addAuth/${site.name}-template".path};"]
                        else [])
                    );
                  };
                  addSSL = true;
                  forceSSL = site.value.rewriteHttps;
                  http2 = site.value.http2;
                };
              })
              (attrsToList nginx.httpProxy));
            recommendedZstdSettings = true;
            recommendedTlsSettings = true;
            recommendedProxySettings = true;
            recommendedOptimisation = true;
            recommendedGzipSettings = true;
            recommendedBrotliSettings = true;
            clientMaxBodySize = "0";
            package =
              let
                nginx-geoip2 =
                {
                  name = "ngx_http_geoip2_module";
                  src = inputs.pkgs.fetchFromGitHub
                  {
                    owner = "leev";
                    repo = "ngx_http_geoip2_module";
                    rev = "a607a41a8115fecfc05b5c283c81532a3d605425";
                    hash = "sha256-CkmaeEa1iEAabJEDu3FhBUR7QF38koGYlyx+pyKZV9Y=";
                  };
                  meta.license = [];
                };
              in
                (inputs.pkgs.nginxMainline.override (prev: { modules = prev.modules ++ [ nginx-geoip2 ]; }))
                  .overrideAttrs (prev: { buildInputs = prev.buildInputs ++ [ inputs.pkgs.libmaxminddb ]; });
            streamConfig =
            ''
              geoip2 ${inputs.config.services.geoipupdate.settings.DatabaseDirectory}/GeoLite2-Country.mmdb
              {
                $geoip2_data_country_code country iso_code;
              }
              resolver 8.8.8.8;
            '';
            # todo: use host dns
            resolver.addresses = [ "8.8.8.8" ];
          };
          geoipupdate =
          {
            enable = true;
            settings =
            {
              AccountID = 901296;
              LicenseKey = inputs.config.sops.secrets."nginx/maxmind-license".path;
              EditionIDs = [ "GeoLite2-ASN" "GeoLite2-City" "GeoLite2-Country" ];
            };
          };
        };
        sops =
        {
          templates = listToAttrs (map
            (site:
            {
              name = "nginx/addAuth/${site.name}-template";
              value =
              {
                content =
                  let placeholder = inputs.config.sops.placeholder."nginx/addAuth/${site.name}";
                  in ''proxy_set_header Authorization "Basic ${placeholder}";'';
                owner = inputs.config.users.users.nginx.name;
              };
            })
            (filter (site: site.value.addAuth) (attrsToList nginx.httpProxy)));
          secrets = { "nginx/maxmind-license".owner = inputs.config.users.users.nginx.name; }
            // (listToAttrs (map
              (site: { name = "nginx/detectAuth/${site.name}"; value.owner = inputs.config.users.users.nginx.name; })
              (filter (site: site.value.detectAuth) (attrsToList nginx.httpProxy))))
            // (listToAttrs (map
              (site: { name = "nginx/addAuth/${site.name}"; value = {}; })
              (filter (site: site.value.addAuth) (attrsToList nginx.httpProxy))));
        };
        systemd.services.nginx.serviceConfig =
        {
          CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];
          AmbientCapabilities = [ "CAP_NET_ADMIN" ];
          LimitNPROC = 65536;
          LimitNOFILE = 524288;
        };
        nixos.services.acme =
        {
          enable = true;
          certs = map (cert: cert.name) (attrsToList nginx.httpProxy);
        };
        security.acme.certs = listToAttrs (map
          (cert: { inherit (cert) name; value.group = inputs.config.services.nginx.group; })
          (attrsToList nginx.httpProxy));
      })
      (mkIf nginx.transparentProxy.enable
      {
        services.nginx.streamConfig =
        ''
          log_format transparent_proxy '[$time_local] $remote_addr-$geoip2_data_country_code '
            '"$ssl_preread_server_name"->$transparent_proxy_backend $bytes_sent $bytes_received';
          map $ssl_preread_server_name $transparent_proxy_backend
          {
            ${concatStringsSep "\n" (map
              (x: ''                  "${x.name}" 127.0.0.1:${toString x.value};'')
              (
                (attrsToList nginx.transparentProxy.map)
                ++ (map
                  (site: { name = site.name; value = (if site.value.http2 then 443 else 3065); })
                  (attrsToList nginx.httpProxy)
                )
              ))}
            default 127.0.0.1:443;
          }
          server
          {
            listen ${nginx.transparentProxy.externalIp}:443;
            ssl_preread on;
            proxy_bind $remote_addr transparent;
            proxy_pass $transparent_proxy_backend;
            proxy_connect_timeout 1s;
            proxy_socket_keepalive on;
            proxy_buffer_size 128k;
            access_log syslog:server=unix:/dev/log transparent_proxy;
          }
        '';
        networking.firewall.allowedTCPPorts = [ 80 443 ];
        systemd.services.nginx-proxy =
          let
            ipset = "${inputs.pkgs.ipset}/bin/ipset";
            iptables = "${inputs.pkgs.iptables}/bin/iptables";
            ip = "${inputs.pkgs.iproute}/bin/ip";
            start = inputs.pkgs.writeShellScript "nginx-proxy.start"
            (
              ''
                ${ipset} create nginx_proxy_port bitmap:port range 0-65535
                ${iptables} -t mangle -N nginx_proxy_mark
                ${iptables} -t mangle -A OUTPUT -j nginx_proxy_mark
                ${iptables} -t mangle -A nginx_proxy_mark -s 127.0.0.1 -p tcp \
                  -m set --match-set nginx_proxy_port src -j MARK --set-mark 2/2
                ${iptables} -t mangle -N nginx_proxy
                ${iptables} -t mangle -A PREROUTING -j nginx_proxy
                ${iptables} -t mangle -A nginx_proxy -s 127.0.0.1 -p tcp \
                  -m set --match-set nginx_proxy_port src -j MARK --set-mark 2/2
                ${ip} rule add fwmark 2/2 table 200
                ${ip} route add local 0.0.0.0/0 dev lo table 200
              ''
              + concatStringsSep "\n" (map
                (port: ''${ipset} add nginx_proxy_port ${toString port}'')
                (inputs.lib.unique ((attrValues nginx.transparentProxy.map) ++ [ 443 3065 ])))
            );
            stop = inputs.pkgs.writeShellScript "nginx-proxy.stop"
            ''
              ${iptables} -t mangle -F nginx_proxy_mark
              ${iptables} -t mangle -D OUTPUT -j nginx_proxy_mark
              ${iptables} -t mangle -X nginx_proxy_mark
              ${iptables} -t mangle -F nginx_proxy
              ${iptables} -t mangle -D PREROUTING -j nginx_proxy
              ${iptables} -t mangle -X nginx_proxy
              ${ip} rule del fwmark 2/2 table 200
              ${ip} route del local 0.0.0.0/0 dev lo table 200
              ${ipset} destroy nginx_proxy_port
            '';
          in
          {
            description = "nginx transparent proxy";
            after = [ "network.target" ];
            serviceConfig =
            {
              Type = "simple";
              RemainAfterExit = true;
              ExecStart = start;
              ExecStop = stop;
            };
            wants = [ "network.target" ];
            wantedBy= [ "multi-user.target" ];
          };
      })
      (mkIf nginx.streamProxy.enable
      {
        services.nginx =
        {
          streamConfig =
          ''
            log_format stream_proxy '[$time_local] $remote_addr-$geoip2_data_country_code '
              '"$ssl_preread_server_name"->$stream_proxy_backend $bytes_sent $bytes_received';
            map $ssl_preread_server_name $stream_proxy_backend
            {
              ${concatStringsSep "\n" (map
                (x: ''                  "${x.name}" "${x.value.upstream or x.value}";'')
                (attrsToList nginx.streamProxy.map))}
            }
            server
            {
              listen 127.0.0.1:${toString nginx.streamProxy.port};
              ssl_preread on;
              proxy_pass $stream_proxy_backend;
              proxy_connect_timeout 10s;
              proxy_socket_keepalive on;
              proxy_buffer_size 128k;
              access_log syslog:server=unix:/dev/log stream_proxy;
            }
          '';
          virtualHosts = listToAttrs (map
            (site:
            {
              inherit (site) name;
              value =
              {
                serverName = site.name;
                listen = [ { addr = "0.0.0.0"; port = 80; } ];
                locations."/".return = "301 http://${site.name}$request_uri";
              };
            })
            (filter (site: site.value.rewriteHttps or false) (attrsToList nginx.streamProxy.map)));
        };
        nixos.services.nginx.transparentProxy.map = listToAttrs (map
          (site: { name = site.name; value = nginx.streamProxy.port; })
          (attrsToList nginx.streamProxy.map));
      })
    ];
}
