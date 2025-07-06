inputs:
{
  options.nixos.services.nginx = let inherit (inputs.lib) mkOption types; in
  {
    https = mkOption
    {
      type = types.attrsOf (types.submodule (siteSubmoduleInputs: { options =
      {
        global =
        {
          configName = mkOption
          {
            type = types.nonEmptyStr;
            default = "https:${siteSubmoduleInputs.config._module.args.name}";
          };
          root = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
          index = mkOption
          {
            type = types.nullOr (types.oneOf [ (types.enum [ "auto" ]) (types.nonEmptyListOf types.nonEmptyStr) ]);
            default = null;
          };
          charset = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
          detectAuth = mkOption
          {
            type = types.nullOr (types.submodule { options =
            {
              text = mkOption { type = types.nonEmptyStr; default = "Restricted Content"; };
              users = mkOption { type = types.nonEmptyListOf types.nonEmptyStr; };
            };});
            default = null;
          };
          rewriteHttps = mkOption { type = types.bool; default = true; };
          tlsCert = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
        };
        listen = mkOption
        {
          type = types.attrsOf (types.submodule { options =
          {
            http2 = mkOption { type = types.bool; default = true; };
            proxyProtocol = mkOption { type = types.bool; default = true; };
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
                # should be set to non null value if global root is null
                root = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
                detectAuth = mkOption
                {
                  type = types.nullOr (types.submodule { options =
                  {
                    text = mkOption { type = types.nonEmptyStr; default = "Restricted Content"; };
                    users = mkOption { type = types.nonEmptyListOf types.nonEmptyStr; };
                  };});
                  default = null;
                };
              };
            in
            {
              # only one should be specified
              proxy = mkOption
              {
                type = types.nullOr (types.submodule { options =
                {
                  inherit (genericOptions) detectAuth;
                  upstream = mkOption { type = types.nonEmptyStr; };
                  websocket = mkOption { type = types.bool; default = false; };
                  grpc = mkOption { type = types.bool; default = false; };
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
                type = types.nullOr (types.submodule { options =
                {
                  inherit (genericOptions) detectAuth root;
                  index = mkOption
                  {
                    type = types.nullOr
                      (types.oneOf [ (types.enum [ "auto" ]) (types.nonEmptyListOf types.nonEmptyStr) ]);
                    default = null;
                  };
                  charset = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
                  tryFiles = mkOption { type = types.nullOr (types.nonEmptyListOf types.nonEmptyStr); default = null; };
                  webdav = mkOption { type = types.bool; default = false; };
                };});
                default = null;
              };
              php = mkOption
              {
                type = types.nullOr (types.submodule { options =
                  { inherit (genericOptions) detectAuth root; fastcgiPass = mkOption { type = types.nonEmptyStr; };};});
                default = null;
              };
              return = mkOption
              {
                type = types.nullOr (types.submodule { options =
                  { return = mkOption { type = types.nonEmptyStr; }; };});
                default = null;
              };
              cgi = mkOption
              {
                type = types.nullOr (types.submodule { options = { inherit (genericOptions) detectAuth root; };});
                default = null;
              };
              alias = mkOption
              {
                type = types.nullOr (types.submodule { options =
                {
                  path = mkOption { type = types.nonEmptyStr; };
                };});
                default = null;
              };
            };});
          default = {};
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
      # https assertions
      {
        # only one type should be specified in each location
        assertions =
        (
          (map
            (location:
            {
              assertion = (inputs.lib.count
                (x: x != null)
                (map (type: location.value.${type}) nginx.global.httpsLocationTypes)) <= 1;
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
      }
      # https
      (
        let
          # merge different types of locations
          sites = map
            (site:
            {
              inherit (site) name;
              value =
              {
                inherit (site.value) global;
                listens = attrValues site.value.listen;
                locations = map
                  (location:
                  {
                    inherit (location) name;
                    value = 
                      let _ = builtins.head (filter (type: type.value != null) (attrsToList location.value));
                      in _.value // { type = _.name; };
                  })
                  (attrsToList site.value.location);
              };
            })
            (attrsToList nginx.https);
        in
        {
          services =
          {
            nginx.virtualHosts = listToAttrs (map
              (site:
              {
                name = site.value.global.configName;
                value =
                {
                  serverName = site.name;
                  root = inputs.lib.mkIf (site.value.global.root != null) site.value.global.root;
                  basicAuthFile = inputs.lib.mkIf (site.value.global.detectAuth != null)
                  (
                    let secret = "nginx/templates/detectAuth/${inputs.lib.strings.escapeURL site.name}-global";
                    in inputs.config.sops.templates.${secret}.path
                  );
                  extraConfig = concatStringsSep "\n"
                  (
                    (
                      let inherit (site.value.global) index; in
                        if (builtins.typeOf index == "list") then [ "index ${concatStringsSep " " index};" ]
                        else if (index == "auto") then [ "autoindex on;" ]
                        else []
                    )
                    ++ (
                      let inherit (site.value.global) detectAuth; in
                        if (detectAuth != null) then [ ''auth_basic "${detectAuth.text}"'' ] else []
                    )
                    ++ (
                      let inherit (site.value.global) charset; in
                        if (charset != null) then [ "charset ${charset};" ] else []
                    )
                  );
                  listen = map
                    (listen:
                    {
                      addr = if listen.proxyProtocol then "0.0.0.0" else "127.0.0.1";
                      port = with nginx.global; httpsPort
                        + (if listen.http2 then httpsPortShift.http2 else 0)
                        + (if listen.proxyProtocol then httpsPortShift.proxyProtocol else 0);
                      ssl = true;
                      proxyProtocol = listen.proxyProtocol;
                      extraParameters = inputs.lib.mkIf listen.http2 [ "http2" ];
                    })
                    site.value.listens;
                  # do not automatically add http2 listen
                  http2 = false;
                  onlySSL = true;
                  useACMEHost = inputs.lib.mkIf (site.value.global.tlsCert == null) site.name;
                  sslCertificate = inputs.lib.mkIf (site.value.global.tlsCert != null)
                    "${site.value.global.tlsCert}/fullchain.pem";
                  sslCertificateKey = inputs.lib.mkIf (site.value.global.tlsCert != null)
                    "${site.value.global.tlsCert}/privkey.pem";
                  locations = listToAttrs (map
                  (location:
                  {
                    inherit (location) name;
                    value =
                    {
                      basicAuthFile = inputs.lib.mkIf (location.value.detectAuth or null != null)
                      (
                        let
                          inherit (inputs.lib.strings) escapeURL;
                          secret = "nginx/templates/detectAuth/${escapeURL site.name}/${escapeURL location.name}";
                        in inputs.config.sops.templates.${secret}.path
                      );
                      root = inputs.lib.mkIf (location.value.root or null != null) location.value.root;
                    }
                    // {
                      proxy =
                      {
                        proxyWebsockets = location.value.websocket;
                        recommendedProxySettings = false;
                        recommendedProxySettingsNoHost = true;
                        extraConfig = concatStringsSep "\n"
                        (
                          [ "${if location.value.grpc then "grpc" else "proxy"}_pass ${location.value.upstream};" ]
                          ++ (map
                            (header: ''proxy_set_header ${header.name} "${header.value}";'')
                            (attrsToList location.value.setHeaders))
                          ++ (
                            if location.value.detectAuth != null || site.value.global.detectAuth != null
                              then [ "proxy_hide_header Authorization;" ]
                              else []
                          )
                          ++ (
                            if location.value.addAuth != null then
                              let authFile = "nginx/templates/addAuth/${location.value.addAuth}";
                              in [ "include ${inputs.config.sops.templates.${authFile}.path};" ]
                            else [])
                        );
                      };
                      static =
                      {
                        index = inputs.lib.mkIf (builtins.typeOf location.value.index == "list")
                          (concatStringsSep " " location.value.index);
                        tryFiles = inputs.lib.mkIf (location.value.tryFiles != null)
                          (concatStringsSep " " location.value.tryFiles);
                        extraConfig = inputs.lib.mkMerge
                        [
                          (inputs.lib.mkIf (location.value.index == "auto") "autoindex on;")
                          (inputs.lib.mkIf (location.value.charset != null) "charset ${location.value.charset};")
                          (inputs.lib.mkIf location.value.webdav
                          ''
                            dav_access user:rw group:rw;
                            dav_methods PUT DELETE MKCOL COPY MOVE;
                            dav_ext_methods PROPFIND OPTIONS;
                            create_full_put_path on;
                          '')
                        ];
                      };
                      php.extraConfig =
                      ''
                        fastcgi_pass ${location.value.fastcgiPass};
                        fastcgi_split_path_info ^(.+\.php)(/.*)$;
                        fastcgi_param PATH_INFO $fastcgi_path_info;
                        include ${inputs.config.services.nginx.package}/conf/fastcgi.conf;
                      '';
                      return.return = location.value.return;
                      cgi.extraConfig =
                      ''
                        include ${inputs.config.services.nginx.package}/conf/fastcgi.conf;
                        fastcgi_pass unix:${inputs.config.services.fcgiwrap.socketAddress};
                        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
                      '';
                      alias.alias = location.value.path;
                    }.${location.value.type};
                  })
                  site.value.locations);
                };
              })
              sites);
            fcgiwrap = inputs.lib.mkIf
            (
              filter (site: site != []) (map
                (site: filter (location: location.value.type == "cgi") site.value.locations)
                sites)
              != []
            )
              (with inputs.config.users.users.nginx; { enable = true; user = name; inherit group; });
          };
          nixos.services =
          {
            nginx =
              let
                # { name = domain; value = listen = { http2 = xxx, proxyProtocol = xxx }; }
                listens = filter
                  (listen: listen.value.addToTransparentProxy)
                  (concatLists (map
                    (site: map (listen: { inherit (site) name; value = listen; }) site.value.listens)
                    sites));
              in
              {
                transparentProxy.map = listToAttrs (map
                  (site:
                  {
                    inherit (site) name;
                    value = with nginx.global; httpsPort + (if site.value.http2 then httpsPortShift.http2 else 0);
                  })
                  (filter (listen: !listen.value.proxyProtocol) listens));
                streamProxy.map = listToAttrs (map
                  (site:
                  {
                    inherit (site) name;
                    value =
                    {
                      upstream.port = with nginx.global; httpsPort + httpsPortShift.proxyProtocol
                        + (if site.value.http2 then httpsPortShift.http2 else 0);
                      proxyProtocol = true;
                      rewriteHttps = inputs.lib.mkDefault false;
                    };
                  })
                  (filter (listen: listen.value.proxyProtocol) listens));
                http = listToAttrs (map
                  (site: { inherit (site) name; value.rewriteHttps = {}; })
                  (filter (site: site.value.global.rewriteHttps) sites));
              };
            acme.cert = listToAttrs (map
              (site: { inherit (site) name; value.group = inputs.config.services.nginx.group; })
              sites);
          };
          sops =
            let
              inherit (inputs.lib.strings) escapeURL;
              detectAuthUsers = concatLists (map
                (site:
                (
                  (map
                    (location:
                    {
                      name = "${escapeURL site.name}/${escapeURL location.name}";
                      value = location.value.detectAuth.users;
                    })
                    (filter (location: location.value.detectAuth or null != null) site.value.locations))
                  ++ (if site.value.global.detectAuth != null then
                    [ { name = "${escapeURL site.name}-global"; value = site.value.global.detectAuth.users; } ]
                    else [])
                ))
                sites);
              addAuth = concatLists (map
                (site: map
                  (location:
                  {
                    name = "${escapeURL site.name}/${escapeURL location.name}";
                    value = location.value.addAuth;
                  })
                  (filter (location: location.value.addAuth or null != null) site.value.locations)
                )
                sites);
            in
            {
              templates = listToAttrs
              (
                (map
                  (detectAuth:
                  {
                    name = "nginx/templates/detectAuth/${detectAuth.name}";
                    value =
                    {
                      owner = inputs.config.users.users.nginx.name;
                      content = concatStringsSep "\n" (map
                        (user: "${user}:{PLAIN}${inputs.config.sops.placeholder."nginx/detectAuth/${user}"}")
                        detectAuth.value);
                    };
                  })
                  detectAuthUsers)
                ++ (map
                  (addAuth:
                  {
                    name = "nginx/templates/addAuth/${addAuth.name}";
                    value =
                    {
                      owner = inputs.config.users.users.nginx.name;
                      content =
                        let placeholder = inputs.config.sops.placeholder."nginx/addAuth/${addAuth.value}";
                        in ''proxy_set_header Authorization "Basic ${placeholder}";'';
                    };
                  })
                  addAuth)
              );
              secrets = listToAttrs
              (
                (map
                  (secret: { name = "nginx/detectAuth/${secret}"; value = {}; })
                  (inputs.lib.unique (concatLists (map (detectAuth: detectAuth.value) detectAuthUsers))))
                ++ (map
                  (secret: { name = "nginx/addAuth/${secret}"; value = {}; })
                  (inputs.lib.unique (map (addAuth: addAuth.value) addAuth)))
              );
            };
        }
      )
    ]);
}
