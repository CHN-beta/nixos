inputs:
{
	options.nixos.services = let inherit (inputs.lib) mkOption types; in
	{
		misskey =
		{
			enable = mkOption { type = types.bool; default = false; };
			port = mkOption { type = types.ints.unsigned; default = 9726; };
			hostname = mkOption { type = types.str; default = "misskey.chn.moe"; };
		};
		misskey-proxy =
		{
			enable = mkOption { type = types.bool; default = false; };
			hostname = mkOption { type = types.str; default = "misskey.chn.moe"; };
		};
	};
	config =
		let
			inherit (inputs.config.nixos.services) misskey misskey-proxy;
			inherit (inputs.localLib) stripeTabs;
			inherit (inputs.lib) mkIf mkMerge;
			inherit (builtins) map listToAttrs toString replaceStrings;
		in mkMerge
		[
			(mkIf misskey.enable
			{
				systemd =
				{
					services.misskey =
					{
						description = "misskey";
						after = [ "network.target" "redis-misskey.service" "postgresql.service" ];
						requires = [ "network.target" "redis-misskey.service" "postgresql.service" ];
						wantedBy = [ "multi-user.target" ];
						environment.MISSKEY_CONFIG_YML = inputs.config.sops.templates."misskey/default.yml".path;
						serviceConfig = rec
						{
							User = inputs.config.users.users.misskey.name;
							Group = inputs.config.users.users.misskey.group;
							WorkingDirectory = "/var/lib/misskey/work";
							ExecStart = "${WorkingDirectory}/bin/misskey";
							CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
							AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
						};
					};
					tmpfiles.rules = [ "d /var/lib/misskey/files 0700 misskey misskey" ];
				};
				fileSystems =
				{
					"/var/lib/misskey/work" =
					{
						device = "${inputs.pkgs.localPackages.misskey}";
						options = [ "bind" ];
					};
					"/var/lib/misskey/work/files" =
					{
						device = "/var/lib/misskey/files";
						options = [ "bind" ];
					};
				};
				sops.templates."misskey/default.yml" =
				{
					content =
						let
							placeholder = inputs.config.sops.placeholder;
							misskey = inputs.config.nixos.services.misskey;
							redis = inputs.config.nixos.services.redis.instances.misskey;
						in replaceStrings ["\t"] ["  "] (stripeTabs
						''
							url: https://${misskey.hostname}/
							port: ${toString misskey.port}
							db:
								host: 127.0.0.1
								port: 5432
								db: misskey
								user: misskey
								pass: ${placeholder."postgresql/misskey"}
							dbReplications: false
							redis:
								host: 127.0.0.1
								port: ${toString redis.port}
								pass: ${placeholder."redis/misskey"}
							id: 'aid'
							proxyBypassHosts:
								- api.deepl.com
								- api-free.deepl.com
								- www.recaptcha.net
								- hcaptcha.com
								- challenges.cloudflare.com
							proxyRemoteFiles: true
							signToActivityPubGet: true
							maxFileSize: 1073741824
						'');
					owner = inputs.config.users.users.misskey.name;
				};
				users =
				{
					users.misskey = { isSystemUser = true; group = "misskey"; home = "/var/lib/misskey"; createHome = true; };
					groups.misskey = {};
				};
				nixos.services =
				{
					redis.instances.misskey.port = 3545;
					nginx =
					{
						enable = true;
						httpProxy =
						{
							"${misskey.hostname}" = { upstream = "http://127.0.0.1:${toString misskey.port}"; websocket = true; };
							"direct.${misskey.hostname}" =
							{
								upstream = "http://127.0.0.1:${toString misskey.port}";
								websocket = true;
								setHeaders.Host = "${misskey.hostname}";
								detectAuth = true;
							};
						};
					};
					postgresql = { enable = true; instances.misskey = {}; };
				};
			})
			(mkIf misskey-proxy.enable
			{
				nixos.services.nginx.httpProxy."${misskey-proxy.hostname}" =
				{
					upstream = "https://direct.${misskey-proxy.hostname}";
					websocket = true;
					setHeaders.Host = "direct.${misskey-proxy.hostname}";
					addAuth = true;
				};
			})
		];
}
