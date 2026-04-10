{ lib, config, ... }:
{
  options.nixos.services.nginx.streamProxy =
  {
    map = lib.mkOption
    {
      type = lib.types.attrsOf (lib.types.oneOf
      [
        # proxy to specified ip:port without proxyProtocol
        lib.types.nonEmptyStr
        (lib.types.submodule { options =
        {
          upstream = lib.mkOption
          {
            type = lib.types.oneOf
            [
              # proxy to specified ip:port with or without proxyProtocol
              lib.types.nonEmptyStr
              (lib.types.submodule { options =
              {
                address = lib.mkOption { type = lib.types.nonEmptyStr; default = "127.0.0.1"; };
                # if port not specified, guess from proxyProtocol enabled or not, assume http2 enabled
                port = lib.mkOption { type = lib.types.nullOr lib.types.ints.unsigned; default = null; };
              };})
            ];
            default = {};
          };
          proxyProtocol = lib.mkOption { type = lib.types.bool; default = true; };
          addToTransparentProxy = lib.mkOption { type = lib.types.bool; default = true; };
          rewriteHttps = lib.mkOption { type = lib.types.bool; default = true; };
        };})
      ]);
      default = {};
    };
  };
  config = let inherit (config.nixos.services) nginx; in lib.mkIf (nginx.streamProxy.map != {})
  {
    services.nginx.streamConfig =
    ''
      log_format stream_proxy '[$time_local] $remote_addr-$geoip2_data_country_code '
        '"$ssl_preread_server_name"->$stream_proxy_backend $bytes_sent $bytes_received';
      map $ssl_preread_server_name $stream_proxy_backend {
        ${builtins.concatStringsSep "\n    " (lib.mapAttrsToList
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
            (lib.attrsToList nginx.streamProxy.map)))
        ++ (builtins.map
          (site: { inherit (site) name; value = with nginx.global; streamPort + streamPortShift.proxyProtocol; })
          (builtins.filter
            (site: ((site.value.proxyProtocol or false) && (site.value.addToTransparentProxy or true)))
            (lib.attrsToList nginx.streamProxy.map)))
      );
      http = builtins.listToAttrs (builtins.map
        (site: { inherit (site) name; value.rewriteHttps = {}; })
        (builtins.filter (site: site.value.rewriteHttps or false) (lib.attrsToList nginx.streamProxy.map)));
    };
  };
}
