inputs:
{
  options.nixos.services.nginx = let inherit (inputs.lib) mkOption types; in
  {
    http = mkOption
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
            websocket = mkOption { type = types.bool; default = false; };
            setHeaders = mkOption
            {
              type = types.attrsOf types.str;
              default.Host = submoduleInputs.config._module.args.name;
            };
          };});
          default = null;
        };
      };}));
      default = {};
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
        assertions = map
          (site:
          {
            assertion = (inputs.lib.count (x: x != null) (map (type: site.value.${type}) nginx.global.httpTypes)) <= 1;
            message = "Only one type shuold be specified in ${site.name}";
          })
          (attrsToList nginx.http);
        services.nginx.virtualHosts = listToAttrs (map
          (site:
          {
            name = "http.${site.name}";
            value = { serverName = site.name; listen = [ { addr = "0.0.0.0"; port = 80; } ]; }
            // (if site.value.rewriteHttps != null then
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
              else {})
            // (if site.value.proxy != null then
              {
                locations."/" =
                {
                  proxyPass = site.value.proxy.upstream;
                  proxyWebsockets = site.value.proxy.websocket;
                  recommendedProxySettings = false;
                  recommendedProxySettingsNoHost = true;
                  extraConfig = builtins.concatStringsSep "\n" (builtins.map
                    (header: ''proxy_set_header ${header.name} "${header.value}";'')
                    (inputs.localLib.attrsToList site.value.proxy.setHeaders));
                };
              }
              else {});
          })
          (attrsToList nginx.http));
      }
    ]);
}
