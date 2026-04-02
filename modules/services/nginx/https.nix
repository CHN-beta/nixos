inputs:
{
  options.nixos.services.nginx.https = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.attrsOf (types.submodule (siteSubmoduleInputs: { options =
    {
      global =
      {
        configName = mkOption
          { type = types.nonEmptyStr; default = "https:${siteSubmoduleInputs.config._module.args.name}"; };
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
        extraConfig = mkOption { type = types.nullOr types.str; default = null; };
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
          let genericOptions =
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
                websocket = mkOption { type = types.bool; default = true; };
                setHeaders = mkOption
                  { type = types.attrsOf types.str; default.Host = siteSubmoduleInputs.config._module.args.name; };
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
              type = types.nullOr (types.submodule { options = { return = mkOption { type = types.nonEmptyStr; }; };});
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
  config = let inherit (inputs.config.nixos.services) nginx; in inputs.lib.mkIf (nginx.https != {}) (inputs.lib.mkMerge
  [
    # https assertions
    {
      # only one type should be specified in each location
      assertions =
      (
        (builtins.map
          (location:
          {
            assertion = 1 >= (inputs.lib.count (x: x != null)
              (builtins.map (type: location.value.${type}) nginx.global.httpsLocationTypes));
            message = "Only one type shuold be specified in ${location.name}";
          })
          (builtins.concatLists (inputs.lib.mapAttrsToList
            (sn: sv: (inputs.lib.mapAttrsToList (ln: lv: inputs.lib.nameValuePair "${sn} ${ln}" lv) sv.location))
            nginx.https)))
        # root should be specified either in global or in each location
        ++ (builtins.map
          (location:
          {
            assertion = (location.value.root or "") != null;
            message = "Root should be specified in ${location.name}";
          })
          (builtins.concatLists (builtins.map
            (site: (inputs.lib.mapAttrsToList
                (n: v: inputs.lib.nameValuePair "${site.name} ${n}" v)
                site.value.location))
            (builtins.filter (site: site.value.global.root == null) (inputs.lib.attrsToList nginx.https)))))
      );
    }
    # https
    (
      # merge different types of locations
      let sites = inputs.lib.mapAttrsToList
        (sn: sv: inputs.lib.nameValuePair sn
        {
          inherit (sv) global;
          listens = builtins.attrValues sv.listen;
          locations = inputs.lib.mapAttrsToList
            (ln: lv: inputs.lib.nameValuePair ln
            (
              let _ = builtins.head (builtins.filter (type: type.value != null) (inputs.lib.attrsToList lv));
              in _.value // { type = _.name; }
            ))
            sv.location;
        })
        nginx.https;
      in
      {
        services.nginx.virtualHosts = builtins.listToAttrs (builtins.map
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
                in inputs.config.nixos.system.sops.templates.${secret}.path
              );
              extraConfig =
                let inherit (site.value.global) index detectAuth charset extraConfig;
                in builtins.concatStringsSep "\n" (builtins.concatLists
                [
                  (
                    if (builtins.typeOf index == "list") then [ "index ${builtins.concatStringsSep " " index};" ]
                    else if (index == "auto") then [ "autoindex on;" ]
                    else []
                  )
                  (inputs.lib.optionals (detectAuth != null) [ ''auth_basic "${detectAuth.text}"'' ])
                  (inputs.lib.optionals (charset != null) [ "charset ${charset};" ])
                  (inputs.lib.optionals (extraConfig != null) [ extraConfig ])
                ]);
              listen = builtins.map
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
              locations = builtins.listToAttrs (builtins.map
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
                      in inputs.config.nixos.system.sops.templates.${secret}.path
                    );
                    root = inputs.lib.mkIf (location.value.root or null != null) location.value.root;
                  }
                  // {
                    proxy =
                    {
                      proxyWebsockets = location.value.websocket;
                      recommendedProxySettings = false;
                      recommendedProxySettingsNoHost = true;
                      proxyPass = location.value.upstream;
                      extraConfig = builtins.concatStringsSep "\n"
                      (
                        (inputs.lib.mapAttrsToList (n: v: ''proxy_set_header ${n} "${v}";'')
                          location.value.setHeaders)
                        ++ (inputs.lib.optionals
                          (location.value.detectAuth != null || site.value.global.detectAuth != null)
                          [ "proxy_hide_header Authorization;" ]
                        )
                        ++ (inputs.lib.optionals (location.value.addAuth != null)
                          (
                            let authFile = "nginx/templates/addAuth/${location.value.addAuth}";
                            in [ "include ${inputs.config.nixos.system.sops.templates.${authFile}.path};" ]
                          ))
                      );
                    };
                    static =
                    {
                      index = inputs.lib.mkIf (builtins.typeOf location.value.index == "list")
                        (builtins.concatStringsSep " " location.value.index);
                      tryFiles = inputs.lib.mkIf (location.value.tryFiles != null)
                        (builtins.concatStringsSep " " location.value.tryFiles);
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
                    alias.alias = location.value.path;
                  }.${location.value.type};
                })
                site.value.locations);
            };
          })
          sites);
        nixos =
        {
          services =
          {
            nginx =
            # { name = domain; value = listen = { http2 = xxx, proxyProtocol = xxx }; }
              let listens = builtins.filter
                (listen: listen.value.addToTransparentProxy)
                (builtins.concatLists (builtins.map
                  (site: builtins.map (listen: { inherit (site) name; value = listen; }) site.value.listens)
                  sites));
              in
              {
                transparentProxy.map = builtins.listToAttrs (builtins.map
                  (site:
                  {
                    inherit (site) name;
                    value = with nginx.global; httpsPort + (if site.value.http2 then httpsPortShift.http2 else 0);
                  })
                  (builtins.filter (listen: !listen.value.proxyProtocol) listens));
                streamProxy.map = builtins.listToAttrs (builtins.map
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
                  (builtins.filter (listen: listen.value.proxyProtocol) listens));
                http = builtins.listToAttrs (builtins.map
                  (site: { inherit (site) name; value.rewriteHttps = {}; })
                  (builtins.filter (site: site.value.global.rewriteHttps) sites));
              };
            acme.cert = builtins.listToAttrs (builtins.map
              (site: { inherit (site) name; value.group = inputs.config.services.nginx.group; })
              sites);
          };
          system.sops =
            let
              inherit (inputs.lib.strings) escapeURL;
              detectAuthUsers = builtins.concatLists (builtins.map
                (site:
                (
                  (builtins.map
                    (location:
                    {
                      name = "${escapeURL site.name}/${escapeURL location.name}";
                      value = location.value.detectAuth.users;
                    })
                    (builtins.filter (location: location.value.detectAuth or null != null) site.value.locations))
                  ++ (inputs.lib.optionals (site.value.global.detectAuth != null)
                    [ { name = "${escapeURL site.name}-global"; value = site.value.global.detectAuth.users; } ])
                ))
                sites);
              addAuth = builtins.concatLists (builtins.map
                (site: builtins.map
                  (location:
                  {
                    name = "${escapeURL site.name}/${escapeURL location.name}";
                    value = location.value.addAuth;
                  })
                  (builtins.filter (location: location.value.addAuth or null != null) site.value.locations)
                )
                sites);
            in
            {
              templates = let inherit (inputs.config.nixos.system.sops) placeholder; in builtins.listToAttrs
              (
                (builtins.map
                  (detectAuth: inputs.lib.nameValuePair "nginx/templates/detectAuth/${detectAuth.name}"
                  {
                    owner = inputs.config.users.users.nginx.name;
                    content = builtins.concatStringsSep "\n" (builtins.map
                      (user: "${user}:{PLAIN}${placeholder."nginx/detectAuth/${user}"}")
                      detectAuth.value);
                  })
                  detectAuthUsers)
                ++ (builtins.map
                  (addAuth: inputs.lib.nameValuePair "nginx/templates/addAuth/${addAuth.name}"
                  {
                    owner = inputs.config.users.users.nginx.name;
                    content =
                      ''proxy_set_header Authorization "Basic ${placeholder."nginx/addAuth/${addAuth.value}"}";'';
                  })
                  addAuth)
              );
              secrets = builtins.listToAttrs
              (
                (builtins.map
                  (secret: { name = "nginx/detectAuth/${secret}"; value = {}; })
                  (inputs.lib.unique (builtins.concatLists (builtins.map (detectAuth: detectAuth.value)
                    detectAuthUsers))))
                ++ (builtins.map
                  (secret: { name = "nginx/addAuth/${secret}"; value = {}; })
                  (inputs.lib.unique (builtins.map (addAuth: addAuth.value) addAuth)))
              );
            };
        };
      }
    )
  ]);
}
