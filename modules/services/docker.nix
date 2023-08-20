inputs:
{
	options.nixos.services.docker = let inherit (inputs.lib) mkOption types; in
	{
		type = types.attrsOf (types.submodule (inputs: { options =
		{
			user = mkOption { type = types.nonEmptyStr; default = inputs.config._module.args.name; };
			image = mkOption { type = types.package; };
			imageName =
				mkOption { type = types.nonEmptyStr; default = "${inputs.image.imageName}:${inputs.image.imageTag}"; };
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
			inherit (inputs.lib) mkMerge mkIf;
			inherit (builtins) listToAttrs map concatLists;
			inherit (inputs.localLib) attrsToList;
		in mkMerge
		[
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
									if builtins.typeOf port == "int" then "127.0.0.1::${toString port}"
									else ("${port.value.hostIp}:${toString port.value.hostPort}"
										+ ":${toString port.value.containerPort}/${port.value.protocol}")
								))
								container.value.ports;
							extraOptions = [ "--add-host=host.docker.internal:host-gateway" ];
							environmentFiles =
								if builtins.typeOf container.value.environmentFile == "bool" && container.value.environmentFile
									then [ inputs.config.sops.templates."${container.name}/env".path ]
								else if builtins.typeOf container.value.environmentFile == "bool" then []
								else [ container.value.environmentFile ];
						};
					})
					(attrsToList services.docker));
				systemd.services = listToAttrs (concatLists (map
					(container:
					[
						{
							name = "docker-${container.value.user}-daemon";
							value =
							{
								wantedBy = [ "multi-user.target" ];
								inherit (inputs.systemd.user.services.docker) description path;
								serviceConfig = inputs.systemd.user.services.docker.serviceConfig //
								{
									User = container.value.user;
									Group = container.value.user;
									AmbientCapabilities = "CAP_NET_BIND_SERVICE";
									ExecStart = inputs.systemd.user.services.docker.serviceConfig.ExecStart
										+ " -H unix:///var/run/docker-rootless/${container.value.user}.sock";
								};
								unitConfig = { inherit (inputs.systemd.user.services.docker.unitConfig) StartLimitInterval; };
							};
						}
						{
							name = "docker-${container.name}";
							value =
							{
								requires = [ "docker-${container.value.user}-daemon.service" ];
								after = [ "docker-${container.value.user}-daemon.service" ];
								environment.DOCKER_HOST = "unix:///var/run/docker-rootless/${container.value.user}.sock";
								serviceConfig = { User = container.value.user; Group = container.value.user; };
							};
						}
					])
					(attrsToList services.docker)));
			}
			(mkIf (services.docker != {})
			{
				systemd.tmpfiles.rules = [ "d /var/run/docker-rootless 0777" ];
				nixos.virtualization.docker.enable = true;
			})
		];
}
