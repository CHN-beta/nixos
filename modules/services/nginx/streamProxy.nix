inputs:
{
  options.nixos.services.nginx = let inherit (inputs.lib) mkOption types; in
  {
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
  };
  config =
    let
      inherit (inputs.localLib) attrsToList;
      inherit (inputs.config.nixos.services) nginx;
      inherit (builtins) map listToAttrs concatStringsSep toString filter attrValues concatLists;
      concatAttrs = list: listToAttrs (concatLists (map (attrs: attrsToList attrs) list));
    in inputs.lib.mkIf nginx.enable (inputs.lib.mkMerge
    [
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
                        port = with nginx.global;
                          if x.value.upstream.port == null then
                            httpsPort + httpsPortShift.http2
                              + (if x.value.proxyProtocol then httpsPortShift.proxyProtocol else 0)
                          else x.value.upstream.port;
                      in "${x.value.upstream.address}:${toString port}";
                in ''"${x.name}" "${upstream}";'')
              (attrsToList nginx.streamProxy.map))}
          }
          server {
            listen 127.0.0.1:${toString nginx.global.streamPort};
            ssl_preread on;
            proxy_pass $stream_proxy_backend;
            proxy_connect_timeout 10s;
            proxy_socket_keepalive on;
            proxy_buffer_size 128k;
            access_log syslog:server=unix:/dev/log stream_proxy;
          }
          server {
            listen 127.0.0.1:${toString (with nginx.global; (streamPort + streamPortShift.proxyProtocol))};
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
              (site: { inherit (site) name; value = nginx.global.streamPort; })
              (filter
                (site: (!(site.value.proxyProtocol or false) && (site.value.addToTransparentProxy or true)))
                (attrsToList nginx.streamProxy.map)))
            ++ (map
              (site: { inherit (site) name; value = with nginx.global; streamPort + streamPortShift.proxyProtocol; })
              (filter
                (site: ((site.value.proxyProtocol or false) && (site.value.addToTransparentProxy or true)))
                (attrsToList nginx.streamProxy.map)))
          );
          http = listToAttrs (map
            (site: { inherit (site) name; value.rewriteHttps = {}; })
            (filter (site: site.value.rewriteHttps or false) (attrsToList nginx.streamProxy.map)));
        };
      }
    ]);
}
