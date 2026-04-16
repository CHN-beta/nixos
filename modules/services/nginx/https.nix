{ lib, config, ... }:
{
  options.nixos.services.nginx.https = lib.mkOption
  {
    type = lib.types.attrsOf (lib.types.submodule (siteSubmoduleInputs: { options =
    {
      global =
      {
        configName = lib.mkOption
          { type = lib.types.nonEmptyStr; default = "https:${siteSubmoduleInputs.config._module.args.name}"; };
        root = lib.mkOption { type = lib.types.nullOr lib.types.nonEmptyStr; default = null; };
        index = lib.mkOption
        {
          type = lib.types.nullOr
            (lib.types.oneOf [ (lib.types.enum [ "auto" ]) (lib.types.nonEmptyListOf lib.types.nonEmptyStr) ]);
          default = null;
        };
        charset = lib.mkOption { type = lib.types.nullOr lib.types.nonEmptyStr; default = null; };
        detectAuth = lib.mkOption
        {
          type = lib.types.nullOr (lib.types.submodule { options =
          {
            text = lib.mkOption { type = lib.types.nonEmptyStr; default = "Restricted Content"; };
            users = lib.mkOption { type = lib.types.nonEmptyListOf lib.types.nonEmptyStr; };
          };});
          default = null;
        };
        rewriteHttps = lib.mkOption { type = lib.types.bool; default = true; };
        tlsCert = lib.mkOption { type = lib.types.nullOr lib.types.nonEmptyStr; default = null; };
        extraConfig = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      };
      listen = lib.mkOption
      {
        type = lib.types.attrsOf (lib.types.submodule { options =
        {
          http2 = lib.mkOption { type = lib.types.bool; default = true; };
          proxyProtocol = lib.mkOption { type = lib.types.bool; default = true; };
          # if proxyProtocol not enabled, add to transparentProxy only
          # if proxyProtocol enabled, add to transparentProxy and streamProxy
          addToTransparentProxy = lib.mkOption { type = lib.types.bool; default = true; };
        };});
        default.main = {};
      };
      location = lib.mkOption
      {
        type = lib.types.attrsOf (lib.types.submodule { options =
          let genericOptions =
          {
            # should be set to non null value if global root is null
            root = lib.mkOption { type = lib.types.nullOr lib.types.nonEmptyStr; default = null; };
            detectAuth = lib.mkOption
            {
              type = lib.types.nullOr (lib.types.submodule { options =
              {
                text = lib.mkOption { type = lib.types.nonEmptyStr; default = "Restricted Content"; };
                users = lib.mkOption { type = lib.types.nonEmptyListOf lib.types.nonEmptyStr; };
              };});
              default = null;
            };
          };
          in
          {
            # only one should be specified
            proxy = lib.mkOption
            {
              type = lib.types.nullOr (lib.types.submodule { options =
              {
                inherit (genericOptions) detectAuth;
                upstream = lib.mkOption { type = lib.types.nonEmptyStr; };
                websocket = lib.mkOption { type = lib.types.bool; default = true; };
                setHeaders = lib.mkOption
                {
                  type = lib.types.attrsOf lib.types.str;
                  default.Host = siteSubmoduleInputs.config._module.args.name;
                };
              };});
              default = null;
            };
            static = lib.mkOption
            {
              type = lib.types.nullOr (lib.types.submodule { options =
              {
                inherit (genericOptions) detectAuth root;
                index = lib.mkOption
                {
                  type = lib.types.nullOr
                    (lib.types.oneOf [ (lib.types.enum [ "auto" ]) (lib.types.nonEmptyListOf lib.types.nonEmptyStr) ]);
                  default = null;
                };
                charset = lib.mkOption { type = lib.types.nullOr lib.types.nonEmptyStr; default = null; };
                tryFiles = lib.mkOption
                  { type = lib.types.nullOr (lib.types.nonEmptyListOf lib.types.nonEmptyStr); default = null; };
                webdav = lib.mkOption { type = lib.types.bool; default = false; };
              };});
              default = null;
            };
            php = lib.mkOption
            {
              type = lib.types.nullOr (lib.types.submodule { options =
              {
                inherit (genericOptions) detectAuth root;
                fastcgiPass = lib.mkOption { type = lib.types.nonEmptyStr; };
              };});
              default = null;
            };
            return = lib.mkOption
            {
              type = lib.types.nullOr
                (lib.types.submodule { options = { return = lib.mkOption { type = lib.types.nonEmptyStr; }; };});
              default = null;
            };
            alias = lib.mkOption
            {
              type = lib.types.nullOr (lib.types.submodule { options =
              {
                path = lib.mkOption { type = lib.types.nonEmptyStr; };
              };});
              default = null;
            };
          };});
        default = {};
      };
    };}));
    default = {};
  };
  config = let inherit (config.nixos.services) nginx; in lib.mkIf (nginx.https != {}) (lib.mkMerge
  [
    # https assertions
    {
      # only one type should be specified in each location
      assertions =
      (
        (builtins.map
          (location:
          {
            assertion = 1 >= (lib.count (x: x != null)
              (builtins.map (type: location.value.${type}) nginx.global.httpsLocationTypes));
            message = "Only one type shuold be specified in ${location.name}";
          })
          (builtins.concatLists (lib.mapAttrsToList
            (sn: sv: (lib.mapAttrsToList (ln: lv: lib.nameValuePair "${sn} ${ln}" lv) sv.location))
            nginx.https)))
        # root should be specified either in global or in each location
        ++ (builtins.map
          (location:
          {
            assertion = (location.value.root or "") != null;
            message = "Root should be specified in ${location.name}";
          })
          (builtins.concatLists (builtins.map
            (site: (lib.mapAttrsToList
                (n: v: lib.nameValuePair "${site.name} ${n}" v)
                site.value.location))
            (builtins.filter (site: site.value.global.root == null) (lib.attrsToList nginx.https)))))
      );
    }
    # https
    (
      # merge different types of locations
      let sites = lib.mapAttrsToList
        (sn: sv: lib.nameValuePair sn
        {
          inherit (sv) global;
          listens = builtins.attrValues sv.listen;
          locations = lib.mapAttrsToList
            (ln: lv: lib.nameValuePair ln
            (
              let _ = builtins.head (builtins.filter (type: type.value != null) (lib.attrsToList lv));
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
              root = lib.mkIf (site.value.global.root != null) site.value.global.root;
              basicAuthFile = lib.mkIf (site.value.global.detectAuth != null)
              (
                let secret = "nginx/templates/detectAuth/${lib.strings.escapeURL site.name}-global";
                in config.nixos.system.sops.templates.${secret}.path
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
                  (lib.optionals (detectAuth != null) [ ''auth_basic "${detectAuth.text}"'' ])
                  (lib.optionals (charset != null) [ "charset ${charset};" ])
                  (lib.optionals (extraConfig != null) [ extraConfig ])
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
                  extraParameters = lib.mkIf listen.http2 [ "http2" ];
                })
                site.value.listens;
              # do not automatically add http2 listen
              http2 = false;
              onlySSL = true;
              useACMEHost = lib.mkIf (site.value.global.tlsCert == null) site.name;
              sslCertificate = lib.mkIf (site.value.global.tlsCert != null)
                "${site.value.global.tlsCert}/fullchain.pem";
              sslCertificateKey = lib.mkIf (site.value.global.tlsCert != null)
                "${site.value.global.tlsCert}/privkey.pem";
              locations = builtins.listToAttrs (builtins.map
                (location:
                {
                  inherit (location) name;
                  value =
                  {
                    basicAuthFile = lib.mkIf (location.value.detectAuth or null != null)
                    (
                      let
                        inherit (lib.strings) escapeURL;
                        secret = "nginx/templates/detectAuth/${escapeURL site.name}/${escapeURL location.name}";
                      in config.nixos.system.sops.templates.${secret}.path
                    );
                    root = lib.mkIf (location.value.root or null != null) location.value.root;
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
                        (lib.mapAttrsToList (n: v: ''proxy_set_header ${n} "${v}";'')
                          location.value.setHeaders)
                        ++ (lib.optionals
                          (location.value.detectAuth != null || site.value.global.detectAuth != null)
                          [ "proxy_hide_header Authorization;" ]
                        )
                      );
                    };
                    static =
                    {
                      index = lib.mkIf (builtins.typeOf location.value.index == "list")
                        (builtins.concatStringsSep " " location.value.index);
                      tryFiles = lib.mkIf (location.value.tryFiles != null)
                        (builtins.concatStringsSep " " location.value.tryFiles);
                      extraConfig = lib.mkMerge
                      [
                        (lib.mkIf (location.value.index == "auto") "autoindex on;")
                        (lib.mkIf (location.value.charset != null) "charset ${location.value.charset};")
                        (lib.mkIf location.value.webdav
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
                      include ${config.services.nginx.package}/conf/fastcgi.conf;
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
                      rewriteHttps = lib.mkDefault false;
                    };
                  })
                  (builtins.filter (listen: listen.value.proxyProtocol) listens));
                http = builtins.listToAttrs (builtins.map
                  (site: { inherit (site) name; value.rewriteHttps = {}; })
                  (builtins.filter (site: site.value.global.rewriteHttps) sites));
              };
            acme.cert = builtins.listToAttrs (builtins.map
              (site: { inherit (site) name; value.group = config.services.nginx.group; })
              sites);
          };
          system.sops =
            let
              inherit (lib.strings) escapeURL;
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
                  ++ (lib.optionals (site.value.global.detectAuth != null)
                    [ { name = "${escapeURL site.name}-global"; value = site.value.global.detectAuth.users; } ])
                ))
                sites);
            in
            {
              templates = let inherit (config.nixos.system.sops) placeholder; in builtins.listToAttrs (builtins.map
                (detectAuth: lib.nameValuePair "nginx/templates/detectAuth/${detectAuth.name}"
                {
                  owner = config.users.users.nginx.name;
                  content = builtins.concatStringsSep "\n" (builtins.map
                    (user: "${user}:{PLAIN}${placeholder."nginx/detectAuth/${user}"}")
                    detectAuth.value);
                })
                detectAuthUsers);
              secrets = builtins.listToAttrs (builtins.map
                (secret: { name = "nginx/detectAuth/${secret}"; value = {}; })
                (lib.unique (builtins.concatLists (builtins.map (detectAuth: detectAuth.value)
                  detectAuthUsers))));
            };
        };
      }
    )
  ]);
}
