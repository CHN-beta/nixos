inputs:
{
	options.nixos.services.rsshub = let inherit (inputs.lib) mkOption types; in
	{
		enable = mkOption { type = types.bool; default = false; };
		port = mkOption { type = types.ints.unsigned; default = 5221; };
		hostname = mkOption { type = types.str; default = "rsshub.chn.moe"; };
	};
	config =
		let
			inherit (inputs.config.nixos.services) rsshub;
			inherit (inputs.localLib) stripeTabs;
			inherit (inputs.lib) mkIf;
			inherit (builtins) map listToAttrs toString;
		in mkIf rsshub.enable
		{
			systemd.services.rsshub =
			{
				description = "rsshub";
				after = [ "network.target" "redis-rsshub.service" ];
				requires = [ "redis-rsshub.service" ];
				wantedBy = [ "multi-user.target" ];
				serviceConfig =
				{
					User = inputs.config.users.users.rsshub.name;
					Group = inputs.config.users.users.rsshub.group;
					EnvironmentFile = inputs.config.sops.templates."rsshub/env".path;
					ExecStart = "${inputs.pkgs.localPackages.rsshub}/bin/rsshub";
				};
			};
			sops =
			{
				templates."rsshub/env".content =
					let
						placeholder = inputs.config.sops.placeholder;
						redis = inputs.config.nixos.services.redis.instances.rsshub;
					in stripeTabs
					''
						PORT='${toString rsshub.port}'
						CACHE_TYPE='redis'
						REDIS_URL='redis://:${placeholder."redis/rsshub"}@127.0.0.1:${toString redis.port}'
						PIXIV_REFRESHTOKEN='${placeholder."rsshub/pixiv-refreshtoken"}'
						YOUTUBE_KEY='${placeholder."rsshub/youtube-key"}'
						YOUTUBE_CLIENT_ID='${placeholder."rsshub/youtube-client-id"}'
						YOUTUBE_CLIENT_SECRET='${placeholder."rsshub/youtube-client-secret"}'
						YOUTUBE_REFRESH_TOKEN='${placeholder."rsshub/youtube-refresh-token"}'
					'';
				secrets = (listToAttrs (map (secret: { name = "rsshub/${secret}"; value = {}; })
				[
					"pixiv-refreshtoken"
					"youtube-key" "youtube-client-id" "youtube-client-secret" "youtube-refresh-token"
				]));
			};
			users = { users.rsshub = { isSystemUser = true; group = "rsshub"; }; groups.rsshub = {}; };
			nixos.services =
			{
				redis.instances.rsshub.port = 7116;
				nginx = { enable = true; httpProxy.${rsshub.hostname}.upstream = "http://127.0.0.1:${toString rsshub.port}"; };
			};
		};
}
