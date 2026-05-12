{ lib, config, ... }:
{
  options.nixos.services.nginx.http = lib.mkOption
  {
    type = lib.types.attrsOf (lib.types.submodule (submoduleInputs: { options =
    {
      rewriteHttps = lib.mkOption
      {
        type = lib.types.nullOr (lib.types.submodule { options =
        {
          hostname = lib.mkOption
            { type = lib.types.nonEmptyStr; default = submoduleInputs.config._module.args.name; }; 
        };});
        default = null;
      };
      php = lib.mkOption
      {
        type = lib.types.nullOr (lib.types.submodule { options =
          { root = lib.mkOption { type = lib.types.nonEmptyStr; }; fastcgiPass = lib.mkOption { type = lib.types.nonEmptyStr; };};});
        default = null;
      };
      proxy = lib.mkOption
      {
        type = lib.types.nullOr (lib.types.submodule { options =
        {
          upstream = lib.mkOption { type = lib.types.nonEmptyStr; };
          websocket = lib.mkOption { type = lib.types.bool; default = true; };
          setHeaders = lib.mkOption
            { type = lib.types.attrsOf lib.types.str; default.Host = submoduleInputs.config._module.args.name; };
        };});
        default = null;
      };
    };}));
    default = {};
  };
  config = let inherit (config.nixos.services) nginx; in lib.mkIf (nginx.http != {})
  {
    assertions = lib.mapAttrsToList
      (n: v:
      {
        assertion = (lib.count (x: x != null) (builtins.map (type: v.${type}) nginx.global.httpTypes)) <= 1;
        message = "Only one type shuold be specified in ${n}";
      })
      nginx.http;
    services.nginx.virtualHosts = lib.mapAttrs'
      (n: v:
      {
        name = "http.${n}";
        value = { serverName = n; listen = [ { addr = "0.0.0.0"; port = 80; } ]; }
        // (lib.optionalAttrs (v.rewriteHttps != null)
          { locations."/".return = "301 https://${v.rewriteHttps.hostname}$request_uri"; })
        // (lib.optionalAttrs (v.php != null)
          {
            extraConfig = "index index.php;";
            root = v.php.root;
            locations."~ ^.+?.php(/.*)?$".extraConfig =
            ''
              fastcgi_pass ${v.php.fastcgiPass};
              fastcgi_split_path_info ^(.+\.php)(/.*)$;
              fastcgi_param PATH_INFO $fastcgi_path_info;
              include ${config.services.nginx.package}/conf/fastcgi.conf;
            '';
          })
        // (lib.optionalAttrs (v.proxy != null)
          {
            locations."/" =
            {
              proxyPass = v.proxy.upstream;
              proxyWebsockets = v.proxy.websocket;
              recommendedProxySettings = false;
              recommendedProxySettingsNoHost = true;
              extraConfig = builtins.concatStringsSep "\n" (lib.mapAttrsToList
                (n: v: ''proxy_set_header ${n} "${v}";'')
                v.proxy.setHeaders);
            };
          });
      })
      nginx.http;
  };
}
