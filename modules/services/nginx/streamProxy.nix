inputs:
{
  options.nixos.services.nginx.streamProxy = let inherit (inputs.lib) mkOption types; in
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
  config = let inherit (inputs.config.nixos.services) nginx; in inputs.lib.mkIf (nginx.streamProxy.map != {})
  {
    services.nginx.streamConfig =
    ''
      log_format stream_proxy '[$time_local] $remote_addr-$geoip2_data_country_code '
        '"$ssl_preread_server_name"->$stream_proxy_backend $bytes_sent $bytes_received';
      map $ssl_preread_server_name $stream_proxy_backend {
        ${builtins.concatStringsSep "\n    " (inputs.lib.mapAttrsToList
          (n: v:
            let
              upstream =
                if (builtins.typeOf v.upstream == "string") then v.upstream
                else
                  let port = with nginx.global;
                    if v.upstream.port == null then
                      httpsPort + httpsPortShift.http2 + (if v.proxyProtocol then httpsPortShift.proxyProtocol else 0)
                    else v.upstream.port;
                  in "${v.upstream.address}:${builtins.toString port}";
            in ''"${n}" "${upstream}";'')
          nginx.streamProxy.map)}
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
        listen 127.0.0.1:${builtins.toString (with nginx.global; (streamPort + streamPortShift.proxyProtocol))};
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
      transparentProxy.map = builtins.listToAttrs
      (
        (builtins.map
          (site: { inherit (site) name; value = nginx.global.streamPort; })
          (builtins.filter
            (site: (!(site.value.proxyProtocol or false) && (site.value.addToTransparentProxy or true)))
            (inputs.lib.attrsToList nginx.streamProxy.map)))
        ++ (builtins.map
          (site: { inherit (site) name; value = with nginx.global; streamPort + streamPortShift.proxyProtocol; })
          (builtins.filter
            (site: ((site.value.proxyProtocol or false) && (site.value.addToTransparentProxy or true)))
            (inputs.lib.attrsToList nginx.streamProxy.map)))
      );
      http = builtins.listToAttrs (builtins.map
        (site: { inherit (site) name; value.rewriteHttps = {}; })
        (builtins.filter (site: site.value.rewriteHttps or false) (inputs.lib.attrsToList nginx.streamProxy.map)));
    };
  };
}
