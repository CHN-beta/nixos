inputs: {
  options.nixos.services.mirism =
    let
      inherit (inputs.lib) mkOption types;
    in
    mkOption {
      type = types.nullOr (types.submodule { });
      default = null;
    };
  config =
    let
      inherit (inputs.config.nixos.services) mirism;
    in
    inputs.lib.mkIf (mirism != null) {
      users = {
        users.mirism = {
          uid = inputs.config.nixos.user.uid.mirism;
          group = "mirism";
          isSystemUser = true;
        };
        groups.mirism.gid = inputs.config.nixos.user.gid.mirism;
      };
      systemd = {
        services = builtins.listToAttrs (
          builtins.map
            (instance: {
              name = "mirism-${instance}";
              value = {
                description = "mirism ${instance}";
                after = [ "network.target" ];
                wantedBy = [ "multi-user.target" ];
                serviceConfig = {
                  User = inputs.config.users.users.mirism.name;
                  Group = inputs.config.users.users.mirism.group;
                  ExecStart = "${inputs.pkgs.localPkgs.mirism-old}/bin/${instance}";
                  RuntimeMaxSec = "1d";
                  Restart = "always";
                };
              };
            })
            [
              "ng01"
              "beta"
            ]
        );
        tmpfiles.rules = builtins.concatLists (
          builtins.map
            (dir: [
              "d /srv/${dir}mirism 0700 nginx nginx"
              "Z /srv/${dir}mirism - nginx nginx"
            ])
            [
              ""
              "entry."
            ]
        );
      };
      nixos.services = {
        nginx = {
          transparentProxy.map = {
            "ng01.mirism.one" = 7411;
            "beta.mirism.one" = 9114;
          };
          https = builtins.listToAttrs (
            builtins.map
              (
                instance:
                inputs.lib.nameValuePair "${instance}mirism.one" {
                  location."/".static = {
                    root = "/srv/${instance}mirism";
                    index = [ "index.html" ];
                  };
                }
              )
              [
                "entry."
                ""
              ]
          );
        };
        acme.cert = {
          "ng01.mirism.one".group = "mirism";
          "beta.mirism.one".group = "mirism";
        };
      };
      environment.etc = builtins.listToAttrs (
        builtins.concatLists (
          builtins.map
            (instance: [
              (inputs.lib.nameValuePair "letsencrypt/live/${instance}.mirism.one/fullchain.pem" {
                source = "${inputs.config.security.acme.certs."${instance}.mirism.one".directory}/fullchain.pem";
              })
              (inputs.lib.nameValuePair "letsencrypt/live/${instance}.mirism.one/privkey.pem" {
                source = "${inputs.config.security.acme.certs."${instance}.mirism.one".directory}/key.pem";
              })
            ])
            [
              "ng01"
              "beta"
            ]
        )
      );
    };
}
