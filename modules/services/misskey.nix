inputs:
{
	options.nixos.services.misskey = let inherit (inputs.lib) mkOption types; in
	{
		enable = mkOption { type = types.bool; default = false; };
		port = mkOption { type = types.ints.unsigned; default = 9726; };
		hostname = mkOption { type = types.str; default = "misskey.chn.moe"; };
	};
	config =
		let
			inherit (inputs.config.nixos.services) misskey;
			inherit (inputs.localLib) stripeTabs;
			inherit (inputs.lib) mkIf;
			inherit (builtins) map listToAttrs toString replaceStrings;
		in mkIf misskey.enable
		{
			systemd.services.misskey =
			{
				description = "misskey";
				after = [ "network.target" "redis-misskey.service" "postgresql.service" ];
				requires = [ "network.target" "redis-misskey.service" "postgresql.service" ];
				wantedBy = [ "multi-user.target" ];
				serviceConfig = rec
				{
					User = inputs.config.users.users.misskey.name;
					Group = inputs.config.users.users.misskey.group;
					WorkingDirectory = "${inputs.config.users.users.misskey.home}/work";
					BindPaths =
					[
						"${inputs.pkgs.localPackages.misskey},${WorkingDirectory}"
						"${inputs.config.sops.templates."misskey/default.yml".path;},${WorkingDirectory}/.config/default.yml"
						"${WorkingDirectory}/files,${WorkingDirectory}/files"
					];
					ExecStartPre = [ "${inputs.pkgs.coreutils}/bin/mkdir -m 700 -p ${WorkingDirectory}/files" ];
					ExecStart = "${WorkingDirectory}/bin/misskey";
					CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
					AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
				};
			};
			sops.templates."misskey/default.yml".content =
				let
					placeholder = inputs.config.sops.placeholder;
					misskey = inputs.config.nixos.services.misskey;
					redis = inputs.config.nixos.services.redis.instances.misskey;
				in replaceStrings "\t" "  " (stripeTabs
				''
					url: https://${misskey.hostname}/
					port: ${toString misskey.port}
					db:
						host: 127.0.0.1
						port: 5432
						db: misskey
						user: misskey
						pass: ${placeholder."postgres/misskey"}
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
			users =
			{
				users.misskey = { isSystemUser = true; group = "misskey"; home = "/var/lib/misskey"; createHome = true; };
				groups.misskey = {};
			};
			nixos.services =
			{
				redis.instances.misskey.port = 3545;
				nginx =
					{ enable = true; httpProxy.${misskey.hostname}.upstream = "http://127.0.0.1:${toString misskey.port}"; };
				postgresql = { enable = true; instances.misskey = {}; };
			};
		};
}
