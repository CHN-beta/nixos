inputs:
{
	options.nixos.services.meilisearch = let inherit (inputs.lib) mkOption types; in
	{
		instances = mkOption
		{
			type = types.attrsOf (types.submodule (submoduleInputs: { options =
			{
				user = mkOption { type = types.nonEmptyStr; default = submoduleInputs.config._module.args.name; };
				port = mkOption { type = types.ints.unsigned; };
			};}));
			default = {};
		};
	};
	config =
		let
			inherit (inputs.config.nixos.services) meilisearch;
			inherit (inputs.localLib) stripeTabs attrsToList;
			inherit (builtins) map listToAttrs;
		in
		{
			systemd =
			{
				services = listToAttrs (map
					(instance:
					{
						name = "meilisearch-${instance.name}";
						value =
						{
							description = "meiliSearch ${instance.name}";
							wantedBy = [ "multi-user.target" ];
							after = [ "network.target" ];
							serviceConfig =
							{
								User = instance.value.user;
								Group = inputs.config.users.users.${instance.value.user}.group;
								ExecStart = "${inputs.pkgs.pkgsStatic.genericPackages.meilisearch}/bin/meilisearch"
									+ " --config-file-path ${inputs.config.sops.templates."meilisearch-${instance.name}.toml".path}";
								Restart = "always";
								StartLimitBurst = 3;
								LimitNOFILE = "infinity";
								LimitNPROC = "infinity";
								LimitCORE = "infinity";
							};
						};
					})
					(attrsToList meilisearch.instances));
				tmpfiles.rules = map
					(instance:
						let
							user = instance.value.user;
							group = inputs.config.users.users.${instance.value.user}.group;
						in
							"d /var/lib/meilisearch/${instance.name} 0700 ${user} ${group}")
					(attrsToList meilisearch.instances);
			};
			sops =
			{
				templates = listToAttrs (map
					(instance:
					{
						name = "meilisearch-${instance.name}.toml";
						value =
						{
							content = stripeTabs
							''
								db_path = "/var/lib/meilisearch/${instance.name}"
								http_addr = "0.0.0.0:${toString instance.value.port}"
								master_key = "${inputs.config.sops.placeholder."meilisearch/${instance.name}"}"
								env = "production"
								dump_dir = "/var/lib/meilisearch/${instance.name}/dumps"
								log_level = "INFO"
								max_indexing_memory = "2Gb"
							'';
							owner = inputs.config.users.users.misskey.name;
						};
					})
					(attrsToList meilisearch.instances));
				secrets = listToAttrs (map
					(instance: { name = "meilisearch/${instance.name}"; value = {}; })
					(attrsToList meilisearch.instances));
			};
		};
}
