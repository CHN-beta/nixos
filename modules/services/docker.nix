inputs:
{
  options.nixos.services.docker = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.attrsOf (types.submodule (inputs: { options =
    {
      user = mkOption { type = types.nonEmptyStr; default = inputs.config._module.args.name; };
      image = mkOption { type = types.package; };
      ports = mkOption
      {
        type = types.listOf (types.oneOf
        [
          types.ints.unsigned
          types.submodule (inputs: { options =
          {
            hostIp = mkOption { type = types.nonEmptyStr; default = "127.0.0.1"; };
            hostPort = mkOption { type = types.ints.unsigned; };
            containerPort = mkOption { type = types.ints.unsigned; };
            protocol = mkOption { type = types.enum [ "tcp" "udp" ]; default = "tcp"; };
          };})
        ]);
        default = [];
      };
      environmentFile = mkOption { type = types.oneOf [ types.bool types.nonEmptyStr ]; default = false; };
    };}));
    default = {};
  };
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (builtins) listToAttrs map;
      inherit (inputs.localLib) attrsToList;
      inherit (inputs.config.nixos.services) docker;
      users = inputs.lib.lists.unique (map (container: container.value.user) (attrsToList docker));
    in mkIf (docker != {})
    {
      systemd.tmpfiles.rules = [ "d /run/docker-rootless 0755 root root" ];
      nixos =
      {
        virtualization.docker.enable = true;
        users.linger = users;
      };
      users =
      {
        users = listToAttrs (map
          (user:
          {
            name = user;
            value =
            {
              isNormalUser = true;
              group = user;
              autoSubUidGidRange = true;
              home = "/run/docker-rootless/${user}";
              createHome = true;
            };
          })
          users);
        groups = listToAttrs (map (user: { name = user; value = {}; }) users);
      };
      home-manager.users = listToAttrs (map
        (user:
        {
          name = user;
          value.config.systemd.user.services = listToAttrs (map
            (container:
            {
              inherit (container) name;
              value =
              {
                Unit =
                {
                  After = [ "dbus.socket" "docker.service" ];
                  Wants = [ "dbus.socket" "docker.service" ];
                };
                Install.WantedBy = [ "default.target" ];
                Service =
                {
                  Type = "simple";
                  RemainAfterExit = true;
                  ExecStart = inputs.pkgs.writeShellScript "docker-${container.name}.start"
                  ''
                    docker rm -f ${container.name} || true
                    echo "loading image"
                    docker load -i ${container.value.image}
                    echo "load finish"
                    docker image ls
                    ${
                      builtins.concatStringsSep " \\\n"
                      (
                        [
                          "docker run --rm --name=${container.name}"
                          "--add-host=host.docker.internal:host-gateway"
                        ]
                        ++ (
                          if (builtins.typeOf container.value.environmentFile) == "string"
                            then [ "--env-file ${container.value.environmentFile}" ]
                          else if container.value.environmentFile
                            then [ "--env-file ${inputs.config.sops.templates."${container.name}.env".path}" ]
                          else []
                        )
                        ++ (map
                          (port: "-p ${port}")
                          (map
                            (port:
                              if builtins.typeOf port == "int" then toString port
                              else "${port.value.hostIp}:${toString port.value.hostPort}"
                                + ":${toString port.value.containerPort}/${port.value.protocol}"
                            )
                            container.value.ports))
                        ++ [ "${container.value.image.imageName}:${container.value.image.imageTag}" ]
                      )
                    }
                  '';
                  ExecStop = inputs.pkgs.writeShellScript "docker-${container.name}.stop"
                  ''
                    docker stop ${container.name}
                    docker system prune --volumes --force
                  '';
                };
              };
            })
            (builtins.filter (container: container.value.user == user) (attrsToList docker)));
        })
        users);
    };
}
