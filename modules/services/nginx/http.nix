inputs:
{
  options.nixos.services.nginx.http = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.attrsOf (types.submodule (submoduleInputs: { options =
    {
      rewriteHttps = mkOption
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
          { root = mkOption { type = types.nonEmptyStr; }; fastcgiPass = mkOption { type = types.nonEmptyStr; };};});
        default = null;
      };
      proxy = mkOption
      {
        type = types.nullOr (types.submodule { options =
        {
          upstream = mkOption { type = types.nonEmptyStr; };
          websocket = mkOption { type = types.bool; default = true; };
          setHeaders = mkOption
            { type = types.attrsOf types.str; default.Host = submoduleInputs.config._module.args.name; };
        };});
        default = null;
      };
    };}));
    default = {};
  };
  config = let inherit (inputs.config.nixos.services) nginx; in inputs.lib.mkIf (nginx.http != {})
  {
    assertions = inputs.lib.mapAttrsToList
      (n: v:
      {
        assertion = (inputs.lib.count (x: x != null) (builtins.map (type: v.${type}) nginx.global.httpTypes)) <= 1;
        message = "Only one type shuold be specified in ${n}";
      })
      nginx.http;
    services.nginx.virtualHosts = inputs.lib.mapAttrs'
      (n: v:
      {
        name = "http.${n}";
        value = { serverName = n; listen = [ { addr = "0.0.0.0"; port = 80; } ]; }
        // (inputs.lib.optionalAttrs (v.rewriteHttps != null)
          { locations."/".return = "301 https://${v.rewriteHttps.hostname}$request_uri"; })
        // (inputs.lib.optionalAttrs (v.php != null)
          {
            extraConfig = "index index.php;";
            root = v.php.root;
            locations."~ ^.+?.php(/.*)?$".extraConfig =
            ''
              fastcgi_pass ${v.php.fastcgiPass};
              fastcgi_split_path_info ^(.+\.php)(/.*)$;
              fastcgi_param PATH_INFO $fastcgi_path_info;
              include ${inputs.config.services.nginx.package}/conf/fastcgi.conf;
            '';
          })
        // (inputs.lib.optionalAttrs (v.proxy != null)
          {
            locations."/" =
            {
              proxyPass = v.proxy.upstream;
              proxyWebsockets = v.proxy.websocket;
              recommendedProxySettings = false;
              recommendedProxySettingsNoHost = true;
              extraConfig = builtins.concatStringsSep "\n" (inputs.lib.mapAttrsToList
                (n: v: ''proxy_set_header ${n} "${v}";'')
                v.proxy.setHeaders);
            };
          });
      })
      nginx.http;
  };
}
