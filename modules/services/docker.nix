inputs:
{
  options.nixos.services.docker = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.attrsOf (types.submodule (inputs: { options =
    {
      user = mkOption { type = types.nonEmptyStr; default = inputs.config._module.args.name; };
      image = mkOption { type = types.package; };
      imageName =
        mkOption { type = types.nonEmptyStr; default = with inputs.config.image; (imageName + ":" + imageTag); };
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
    in mkIf (docker != {})
    {
      virtualisation.oci-containers.containers = listToAttrs (map
        (container:
        {
          name = "${container.name}";
          value =
          {
            image = container.value.imageName;
            imageFile = container.value.image;
            ports = map
              (port:
              (
                if builtins.typeOf port == "int" then toString port
                else ("${port.value.hostIp}:${toString port.value.hostPort}"
                  + ":${toString port.value.containerPort}/${port.value.protocol}")
              ))
              container.value.ports;
            extraOptions = [ "--add-host=host.docker.internal:host-gateway" ];
            environmentFiles =
              if builtins.typeOf container.value.environmentFile == "bool" && container.value.environmentFile
                then [ inputs.config.sops.templates."${container.name}.env".path ]
              else if builtins.typeOf container.value.environmentFile == "bool" then []
              else [ container.value.environmentFile ];
          };
        })
        (attrsToList docker));
      systemd =
      {
        services = listToAttrs (concatLists (map
          (container: let user = container.value.user; in
          [
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
                  # AmbientCapabilities = "CAP_NET_BIND_SERVICE";
                  ExecStart = originalService.serviceConfig.ExecStart
                    + " -H unix:///var/run/docker-rootless/${user}/docker.sock";
                };
                unitConfig = { inherit (originalService.unitConfig) StartLimitInterval; };
              };
            }
            {
              name = "docker-${container.name}";
              value =
              {
                requires = [ "docker-${user}-daemon.service" ];
                after = [ "docker-${user}-daemon.service" ];
                environment =
                {
                  XDG_RUNTIME_DIR = "/run/docker-rootless/${user}";
                  DOCKER_HOST = "unix:///run/docker-rootless/${user}/docker.sock";
                };
                serviceConfig =
                {
                  User = user;
                  Group = user;
                  CapabilityBoundingSet = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
                  AmbientCapabilities = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
                };
              };
            }
          ])
          (attrsToList docker)));
        tmpfiles.rules = map
          (container: with container.value; "d /run/docker-rootless/${user} 0755 ${user} ${user}")
          (attrsToList docker);
      };
      nixos.virtualization.docker.enable = true;
      users =
      {
        users = listToAttrs (map
          (container:
          {
            name = container.value.user;
            value =
            {
              isSystemUser = true;
              group = container.value.user;
              autoSubUidGidRange = true;
              home = "/run/docker-rootless/${container.value.user}";
            };
          })
          (attrsToList docker));
        groups = listToAttrs (map
          (container: { name = container.value.user; value = {}; })
          (attrsToList docker));
      };
    };
}
