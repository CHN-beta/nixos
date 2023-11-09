inputs:
{
  imports = inputs.localLib.mkModules
  [
    ./applications
  ];
  options.nixos.services.nginx = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    # transparentProxy -> https(with proxyProtocol) or transparentProxy -> streamProxy -> https(with proxyProtocol)
    # https without proxyProtocol listen on private ip, with proxyProtocol listen on all ip
    # streamProxy listen on private ip
    # transparentProxy listen on public ip
    transparentProxy =
    {
      # only disable in some rare cases
      enable = mkOption { type = types.bool; default = true; };
      externalIp = mkOption { type = types.listOf types.nonEmptyStr; };
      # proxy to 127.0.0.1:${specified port}
      map = mkOption { type = types.attrsOf types.ints.unsigned; default = {}; };
    };
    streamProxy =
    {
      map = mkOption
      {
        type = types.attrsOf (types.oneOf
        [
          # proxy to specified ip:port without proxyProtocol
          types.nonEmptyStr
          (types.submodule { options =
          {
            upstream = mkOption
            {
              type = types.oneOf
              [
                # proxy to specified ip:port with or without proxyProtocol
                types.nonEmptyStr
                (types.submodule { options =
                {
                  address = mkOption { type = types.nonEmptyStr; default = "127.0.0.1"; };
                  # if port not specified, guess from proxyProtocol enabled or not, assume http2 enabled
                  port = mkOption { type = types.nullOr types.ints.unsigned; default = null; };
                };})
              ];
              default = {};
            };
            proxyProtocol = mkOption { type = types.bool; default = true; };
            addToTransparentProxy = mkOption { type = types.bool; default = true; };
            rewriteHttps = mkOption { type = types.bool; default = true; };
          };})
        ]);
        default = {};
      };
    };
    https = mkOption
    {
      type = types.attrsOf (types.submodule (siteSubmoduleInputs: { options =
      {
        global =
        {
          root = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
          index = mkOption { type = types.nullOr (types.nonEmptyListOf types.nonEmptyStr); default = null; };
          detectAuth = mkOption { type = types.nullOr (types.nonEmptyListOf types.nonEmptyStr); default = null; };
          rewriteHttps = mkOption { type = types.bool; default = true; };
        };
        listen = mkOption
        {
          type = types.attrsOf (types.submodule { options =
          {
            http2 = mkOption { type = types.bool; default = true; };
            proxyProtocol = mkOption { type = types.bool; default = false; };
            # if proxyProtocol not enabled, add to transparentProxy only
            # if proxyProtocol enabled, add to transparentProxy and streamProxy
            addToTransparentProxy = mkOption { type = types.bool; default = true; };
          };});
          default.main = {};
        };
        location = mkOption
        {
          type = types.attrsOf (types.submodule { options =
            let
              genericOptions =
              {
                # htpasswd -n username
                detectAuth = mkOption { type = types.nullOr (types.nonEmptyListOf types.nonEmptyStr); default = null; };
              };
            in
            {
              # only one should be specified
              proxy = mkOption
              {
                type = types.nullOr (types.submodule { options = genericOptions //
                {
                  upstream = mkOption { type = types.nonEmptyStr; };
                  websocket = mkOption { type = types.bool; default = false; };
                  setHeaders = mkOption
                  {
                    type = types.attrsOf types.str;
                    default.Host = siteSubmoduleInputs.config._module.args.name;
                  };
                  # echo -n "username:password" | base64
                  addAuth = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
                };});
                default = null;
              };
              static = mkOption
              {
                type = types.nullOr (types.submodule { options = genericOptions //
                {
                  # should be set to non null value if global root is null
                  root = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
                  index = mkOption { type = types.listOf types.nonEmptyStr; default = [ "index.html" ]; };
                  tryFiles = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
                };});
                default = null;
              };
              php = mkOption
              {
                type = types.nullOr (types.submodule { options = genericOptions //
                {
                  # should be set to non null value if global root is null
                  root = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
                  fastcgiPass = mkOption { type = types.nonEmptyStr; };
                };});
                default = null;
              };
            };});
          default = {};
        };
      };}));
      default = {};
    };
    http = mkOption
    {
      type = types.attrsOf (types.submodule (submoduleInputs: { options =
      {
        rewritetHttps = mkOption
        {
          type = types.nullOr (types.submodule { options =
          {
            hostname = mkOption { type = types.nonEmptyStr; default = submoduleInputs.config._module.args.name; }; 
          };});
          default = null;
        };
        php = mkOption
        {
          type = types.nullOr (types.submodule { options =
          {
            root = mkOption { type = types.nonEmptyStr; };
            fastcgiPass = mkOption { type = types.nonEmptyStr; };
          };});
          default = null;
        };
      };}));
      default = {};
    };
  };
  config =
    let
      inherit (inputs.lib) mkMerge mkIf mkDefault;
      inherit (inputs.lib.string) escapeURL;
      inherit (inputs.localLib) attrsToList;
      inherit (inputs.config.nixos.services) nginx;
      inherit (builtins) map listToAttrs concatStringsSep toString filter attrValues concatLists;
      concatAttrs = list: listToAttrs (concatLists (map (attrs: attrsToList attrs) list));
      httpsPort = 3065;
      httpsPortShift = { http2 = 1; proxyProtocol = 2; };
      httpsLocationTypes = [ "proxy" "static" "php" ];
      httpTypes = [ "rewritetHttps" ];
      streamPort = 5575;
      streamPortShift = { proxyProtocol = 1; };
    in mkIf nginx.enable (mkMerge
    [
      # generic config
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
              geoip2 ${inputs.config.services.geoipupdate.settings.DatabaseDirectory}/GeoLite2-Country.mmdb {
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
        networking.firewall.allowedTCPPorts = [ 80 443 ];
        sops.secrets = { "nginx/maxmind-license".owner = inputs.config.users.users.nginx.name; };
        systemd.services.nginx.serviceConfig =
        {
          CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];
          AmbientCapabilities = [ "CAP_NET_ADMIN" ];
          LimitNPROC = 65536;
          LimitNOFILE = 524288;
        };
      }
      # transparentProxy
      (mkIf nginx.transparentProxy.enable
      {
        services.nginx.streamConfig =
        ''
          log_format transparent_proxy '[$time_local] $remote_addr-$geoip2_data_country_code '
            '"$ssl_preread_server_name"->$transparent_proxy_backend $bytes_sent $bytes_received';
          map $ssl_preread_server_name $transparent_proxy_backend {
            ${concatStringsSep "\n    " (map
              (x: ''"${x.name}" 127.0.0.1:${toString x.value};'')
              (attrsToList nginx.transparentProxy.map))}
            default 127.0.0.1:${toString httpsPort + httpsPortShift.http2};
          }
          server {
            ${concatStringsSep "\n    " (map (ip: "listen ${ip}:443;") nginx.transparentProxy.externalIp)}
            ssl_preread on;
            proxy_bind $remote_addr transparent;
            proxy_pass $transparent_proxy_backend;
            proxy_connect_timeout 1s;
            proxy_socket_keepalive on;
            proxy_buffer_size 128k;
            access_log syslog:server=unix:/dev/log transparent_proxy;
          }
        '';
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
              + concatStringsSep "\n  " (map
                (port: ''${ipset} add nginx_proxy_port ${toString port}'')
                (inputs.lib.unique (attrValues nginx.transparentProxy.map)))
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
      # streamProxy
      {
        services.nginx.streamConfig =
        ''
          log_format stream_proxy '[$time_local] $remote_addr-$geoip2_data_country_code '
            '"$ssl_preread_server_name"->$stream_proxy_backend $bytes_sent $bytes_received';
          map $ssl_preread_server_name $stream_proxy_backend {
            ${concatStringsSep "\n    " (map
              (x:
                let
                  upstream =
                    if (builtins.typeOf x.value.upstream == "string") then
                      x.value.upstream
                    else
                      let
                        port =
                          if x.value.upstream.port == null then
                            httpsPort + httpsPortShift.http2
                              + (if x.value.proxyProtocol then httpsPortShift.proxyProtocol else 0)
                          else streamPort;
                      in "${x.value.upstream.address}:${toString port}";
                in ''"${x.name}" "${upstream}";'')
              (attrsToList nginx.streamProxy.map))}
          }
          server {
            listen 127.0.0.1:${toString streamPort};
            ssl_preread on;
            proxy_pass $stream_proxy_backend;
            proxy_connect_timeout 10s;
            proxy_socket_keepalive on;
            proxy_buffer_size 128k;
            access_log syslog:server=unix:/dev/log stream_proxy;
          }
          server {
            listen 127.0.0.1:${toString (streamPort + streamPortShift.proxyProtocol)};
            proxy_protocol on;
            ssl_preread on;
            proxy_pass $stream_proxy_backend;
            proxy_connect_timeout 10s;
            proxy_socket_keepalive on;
            proxy_buffer_size 128k;
            access_log syslog:server=unix:/dev/log stream_proxy;
          }
        '';
        nixos.services.nginx =
        {
          transparentProxy.map = listToAttrs
          (
            (map
              (site: { inherit (site) name; value = streamPort; })
              (filter
                (site: (!(site.value.proxyProtocol or false) && (site.value.addToTransparentProxy or true)))
                (attrsToList nginx.streamProxy.map)))
            ++ (map
              (site: { inherit (site) name; value = streamPort + streamPortShift.proxyProtocol; })
              (filter
                (site: ((site.value.proxyProtocol or false) && (site.value.addToTransparentProxy or true)))
                (attrsToList nginx.streamProxy.map)))
          );
          http = listToAttrs (map
            (site: { inherit (site) name; value.rewritetHttps = {}; })
            (filter (site: site.value.rewriteHttps or false) (attrsToList nginx.streamProxy.map)));
        };
      }
      # https
      {
        # only one type should be specified in each location
        assertions =
        (
          (map
            (location:
            {
              assertion =
                (inputs.lib.count (x: x != null) (map (type: location.value.${type}) httpsLocationTypes)) <= 1;
              message = "Only one type shuold be specified in ${location.name}";
            })
            (concatLists (map
              (site: (map
                (location: { inherit (location) value; name = "${site.name} ${location.name}"; })
                (attrsToList site.value.location)))
              (attrsToList nginx.https))))
          # root should be specified either in global or in each location
          ++ (map
            (location:
            {
              assertion = (location.value.root or "") != null;
              message = "Root should be specified in ${location.name}";
            })
            (concatLists (map
              (site: (map
                  (location: { inherit (location) value; name = "${site.name} ${location.name}"; })
                  (attrsToList site.value.location)))
              (filter (site: site.value.global.root == null) (attrsToList nginx.https)))))
        );
        services.nginx.virtualHosts = listToAttrs (map
          (site:
          {
            inherit (site) name;
            value =
            {
              serverName = site.name;
              root = mkIf (site.value.global.root != null) site.value.global.root;
              basicAuthFile = mkIf (site.value.global.detectAuth != null)
                inputs.config.sops.templates."nginx/templates/detectAuth/${escapeURL site.name}-global".path;
              extraConfig = mkIf (site.value.global.index != null)
                "index ${concatStringsSep " " site.value.global.index};";
              listen = map
                (listen:
                {
                  add = if listen.value.proxyProtocol then "0.0.0.0" else "127.0.0.1";
                  port = httpsPort
                    + (if listen.value.http2 then httpsPortShift.http2 else 0)
                    + (if listen.value.proxyProtocol then httpsPortShift.proxyProtocol else 0);
                  ssl = true;
                  # TODO: use proxy_protocol in 23.11
                  extraParameters = if listen.value.proxyProtocol then [ "proxy_protocol" ] else [];
                })
                (attrValues site.value.listen);
              # TODO: disable well-known in 23.11
              useACMEHost = site.name;
              http2 = site.value.http2;
              locations = listToAttrs (map
                (location:
                {
                  inherit (location) name;
                  value =
                  {
                    basicAuthFile = mkIf (location.value.detectAuth != null)
                      inputs.config.sops.templates
                        ."nginx/templates/detectAuth/${escapeURL site.name}/${escapeURL location.name}".path;
                  }
                  // (
                    if (location.value.proxy != null) then
                    {
                      proxyPass = location.value.proxy.upstream;
                      proxyWebsockets = location.value.proxy.websocket;
                      recommendedProxySettings = false;
                      recommendedProxySettingsNoHost = true;
                      extraConfig = concatStringsSep "\n"
                      (
                        (map
                          (header: ''proxy_set_header ${header.name} "${header.value}";'')
                          (attrsToList location.value.proxy.setHeaders))
                        ++ (if site.value.detectAuth != null then [ "proxy_hide_header Authorization;" ] else [])
                        ++ (
                          if site.value.addAuth != null then
                            let authFile = "nginx/templates/addAuth/${site.value.addAuth}";
                            in [ "include ${inputs.config.sops.templates.${authFile}.path};" ]
                          else [])
                      );
                    }
                    else if (location.value.static != null) then
                    {
                      root = location.value.static.root;
                      index = mkIf (location.value.static.index != [])
                        (concatStringsSep " " location.value.static.index);
                      tryFiles = mkIf (location.value.static.tryFiles != [])
                        (concatStringsSep " " location.value.static.tryFiles);
                    }
                    else if (location.value.php != null) then
                    {
                      root = location.value.php.root;
                      extraConfig =
                      ''
                        fastcgi_pass ${location.value.php.fastcgiPass};
                        fastcgi_split_path_info ^(.+\.php)(/.*)$;
                        fastcgi_param PATH_INFO $fastcgi_path_info;
                        include ${inputs.config.services.nginx.package}/conf/fastcgi.conf;
                      '';
                    }
                    else {}
                  );
                })
                (attrsToList site.value.location));
            };
          })
          (attrsToList nginx.https));
        nixos.services =
        {
          nginx =
            let
              # { name = domain; value = listen = { http2 = xxx, proxyProtocol = xxx, addToTransparentProxy = true }; }
              listens = filter
                (site: site.value.addToTransparentProxy)
                (concatLists (map
                  (site: map
                    (listen: { inherit (site) name; inherit (listen) value; })
                    (attrsToList site.value.listen))
                  (attrsToList nginx.https)));
            in
            {
              transparentProxy.map = listToAttrs (map
                (site:
                {
                  inherit (site) name;
                  value = httpsPort + (if site.value.http2 then httpsPortShift.http2 else 0);
                })
                (filter (listen: !listen.value.proxyProtocol) listens));
              streamProxy.map = listToAttrs (map
                (site:
                {
                  inherit (site) name;
                  value =
                  {
                    upstream.port = httpsPort + httpsPortShift.proxyProtocol
                      + (if site.value.http2 then httpsPortShift.http2 else 0);
                    proxyProtocol = true;
                    rewiteHttps = mkDefault false;
                  };
                })
                (filter (listen: listen.value.proxyProtocol) listens));
              http = listToAttrs (map
                (site: { inherit (site) name; value.rewritetHttps = {}; })
                (filter (site: site.value.global.rewriteHttps) (attrsToList nginx.https)));
            };
          acme =
          {
            enable = true;
            cert = map
              (site: { inherit (site) name; value.group = inputs.config.services.nginx.group; })
              (attrsToList nginx.https);
          };
        };
        sops =
          let
            locations =
            (
              (concatLists (map
                (site: map
                  (location:
                  {
                    domain = site.name;
                    location = location.name;
                    detectAuth = concatLists (map
                      (type: location.value.${type}.detectAuth or [])
                      httpsLocationTypes);
                    addAuth = location.value.proxy.addAuth or null;
                  })
                  (attrsToList site.value.location))
                (attrsToList nginx.https)))
              ++ (map
                (site:
                {
                  domain = site.name;
                  detectAuth = site.value.global.detectAuth or [];
                })
                (attrsToList nginx.https))
            );
          in
          {
            templates = listToAttrs
            (
              (map
                (location:
                {
                  name =
                    if (location ? location) then
                      "nginx/templates/detectAuth/${escapeURL location.domain}/${escapeURL location.location}"
                    else
                      "nginx/templates/detectAuth/${escapeURL location.domain}-global";
                  value =
                  {
                    owner = inputs.config.users.users.nginx.name;
                    content = concatStringsSep "\n" (map
                      (secret: inputs.config.sops.placeholder."nginx/detectAuth/${secret}")
                      location.detectAuth);
                  };
                })
                (filter (location: location.detectAuth != []) locations))
              ++ (map
                (location:
                {
                  name = "nginx/templates/addAuth/${escapeURL location.domain}/${escapeURL location.location}";
                  value =
                  {
                    owner = inputs.config.users.users.nginx.name;
                    content =
                      let placeholder = inputs.config.sops.placeholder."nginx/addAuth/${location.addAuth}";
                      in ''proxy_set_header Authorization "Basic ${placeholder}";'';
                  };
                })
                (filter (location: (location.addAuth or null) != null) locations))
            );
            secrets = listToAttrs
            (
              (map
                (secret: { name = "nginx/detectAuth/${secret}"; value = {}; })
                (inputs.lib.unique (concatLists (map (location: location.value.detectAuth) locations))))
              ++ (map
                (secret: { name = "nginx/addAuth/${secret}"; value = {}; })
                (inputs.lib.unique (filter
                  (secret: secret != null)
                  (map (location: location.value.addAuth) locations))))
            );
          };
      }
      # http
      {
        assertions = map
          (site:
          {
            assertion = (inputs.lib.count (x: x != null) (map (type: site.value.${type}) httpTypes)) <= 1;
            message = "Only one type shuold be specified in ${site.name}";
          })
          (attrsToList nginx.http);
        services.nginx.virtualHosts = listToAttrs (map
          (site:
          {
            inherit (site) name;
            value =
            {
              serverName = site.name;
              listen = [ { addr = "0.0.0.0"; port = 80; } ];
            }
            // (if site.value.rewritetHttps != null then
              { locations."/".return = "301 https://${site.value.rewriteHttps.hostname}$request_uri"; }
              else {})
            // (if site.value.php != null then
              {
                extraConfig = "index index.php;";
                root = site.value.php.root;
                locations."~ ^.+?.php(/.*)?$".extraConfig =
                ''
                  fastcgi_pass ${site.value.php.fastcgiPass};
                  fastcgi_split_path_info ^(.+\.php)(/.*)$;
                  fastcgi_param PATH_INFO $fastcgi_path_info;
                  include ${inputs.config.services.nginx.package}/conf/fastcgi.conf;
                '';
              }
              else {});
          })
          (attrsToList nginx.http));
      }
    ]);
}
