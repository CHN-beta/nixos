inputs:
{
  options.nixos.services.mirism = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
  };
  config =
    let
      inherit (inputs.config.nixos.services) mirism;
      inherit (inputs.lib) mkIf;
      inherit (builtins) map listToAttrs toString concatLists;
    in mkIf mirism.enable
    {
      users =
      {
        users.mirism = { uid = inputs.config.nixos.user.uid.mirism; group = "mirism"; isSystemUser = true; };
        groups.mirism.gid = inputs.config.nixos.user.gid.mirism;
      };
      systemd =
      {
        services = listToAttrs (map
          (instance:
          {
            name = "mirism-${instance}";
            value =
            {
              description = "mirism ${instance}";
              after = [ "network.target" ];
              wantedBy = [ "multi-user.target" ];
              serviceConfig =
              {
                User = inputs.config.users.users.mirism.name;
                Group = inputs.config.users.users.mirism.group;
                ExecStart = "${inputs.pkgs.localPackages.mirism}/bin/${instance}";
                RuntimeMaxSec = "1d";
                Restart = "always";
              };
            };
          })
          [ "ng01" "beta" ]);
        tmpfiles.rules = concatLists (map
          (dir: [ "d /srv/${dir}mirism 0700 nginx nginx" "Z /srv/${dir}mirism - nginx nginx" ])
          [ "" "entry." ]);
      };
      nixos.services =
      {
        nginx =
        {
          enable = true;
          transparentProxy.map = { "ng01.mirism.one" = 7411; "beta.mirism.one" = 9114; };
          https = listToAttrs (map
            (instance:
            {
              name = "${instance}mirism.one";
              value.location."/".static = { root = "/srv/${instance}mirism"; index = [ "index.html" ]; };
            })
            [ "entry." "" ]);
        };
        acme = { enable = true; cert = { "ng01.mirism.one".group = "mirism"; "beta.mirism.one".group = "mirism"; }; };
      };
      environment.etc = listToAttrs (concatLists (map
        (instance:
        [
          {
            name = "letsencrypt/live/${instance}.mirism.one/fullchain.pem";
            value.source = "${inputs.config.security.acme.certs."${instance}.mirism.one".directory}/fullchain.pem";
          }
          {
            name = "letsencrypt/live/${instance}.mirism.one/privkey.pem";
            value.source = "${inputs.config.security.acme.certs."${instance}.mirism.one".directory}/key.pem";
          }
        ])
        [ "ng01" "beta" ]));
    };
}
