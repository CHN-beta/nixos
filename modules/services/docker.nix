inputs:
{
  options.nixos.services.docker = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.attrsOf (types.submodule (inputs: { options =
    {
      user = mkOption { type = types.nonEmptyStr; default = inputs.config._module.args.name; };
      image = mkOption { type = types.package; };
      # imageName =
      #   mkOption { type = types.nonEmptyStr; default = with inputs.config.image; (imageName + ":" + imageTag); };
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
      inherit (builtins) listToAttrs map concatLists;
      inherit (inputs.localLib) attrsToList;
      inherit (inputs.config.nixos.services) docker;
      users = inputs.lib.lists.unique (map (container: container.value.user) (attrsToList docker));
    in mkIf (docker != {})
    {
      nixos.virtualization.docker.enable = true;
      users =
      {
        users = listToAttrs (map
          (user:
          {
            name = user;
            value =
            {
              isSystemUser = true;
              group = user;
              autoSubUidGidRange = true;
              home = "/run/docker-rootless/${user}";
            };
          })
          users);
        groups = listToAttrs (map (user: { name = user; value = {}; }) users);
      };
      systemd =
      {
        tmpfiles.rules = map (user: "d /run/docker-rootless/${user} 0755 ${user} ${user}") users;
        services = listToAttrs
        (
          (map
            (user:
            {
              name = "docker-${user}-daemon";
              value = let originalService = inputs.config.systemd.user.services.docker; in
              {
                wantedBy = [ "multi-user.target" ];
                inherit (originalService) description path;
                environment.XDG_RUNTIME_DIR = "/run/docker-rootless/${user}";
                serviceConfig = originalService.serviceConfig //
                {
                  User = user;
                  Group = user;
                  # from https://www.reddit.com/r/NixOS/comments/158azri/changing_user_slices_cgroup_controllers
                  Delegate = "memory pids cpu cpuset";
                  ExecStart = originalService.serviceConfig.ExecStart
                    + " -H unix:///var/run/docker-rootless/${user}/docker.sock";
                };
                unitConfig = { inherit (originalService.unitConfig) StartLimitInterval; };
              };
            })
            users)
          ++ (map
            (container:
            {
              name = "docker-${container.name}";
              value =
              {
                requires = [ "docker-${container.value.user}-daemon.service" ];
                after = [ "docker-${container.value.user}-daemon.service" ];
                wantedBy = [ "multi-user.target" ];
                path = [ inputs.config.virtualisation.docker.rootless.package ];
                environment =
                {
                  XDG_RUNTIME_DIR = "/run/docker-rootless/${container.value.user}";
                  DOCKER_HOST = "unix:///run/docker-rootless/${container.value.user}/docker.sock";
                };
                serviceConfig =
                {
                  Type = "simple";
                  RemainAfterExit = true;
                  User = container.value.user;
                  Group = container.value.user;
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
                  # CapabilityBoundingSet = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
                  # AmbientCapabilities = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
                };
              };
            })
            (attrsToList docker))
        );
      };
    };
}
