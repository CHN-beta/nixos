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
			inherit (inputs.lib) mkMerge mkAfter concatStringsSep mkIf;
			inherit (inputs.localLib) stripeTabs attrsToList;
			inherit (builtins) map listToAttrs filter;
		in mkIf meilisearch.enable
		{
			systemd.services = listToAttrs (map
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
							User = instance.user;
							Group = inputs.users.users.${instance.user}.group;
							ExecStart = "${inputs.pkgs.meilisearch}/bin/meilisearch"
								+ " --config-file-path ${inputs.sops.template."meilisearch-${instance.name}.toml".path}";
							StateDirectory = "meilisearch/${instance.name}";
						};
					};
				})
				(attrsToList meilisearch.instances));
			sops =
			{
				template = listToAttrs (map
					(instance:
					{
						name = "meilisearch-${instance.name}.toml";
						value =
						{
							content = stripeTabs
							''
								db_path = "/var/lib/meilisearch/${instance.name}";
								http_addr = "0.0.0.0:${toString instance.port}";
								master_key = "${inputs.sops.placeholder."meilisearch/${instance.name}"}";
								no_analytics = false;
								env = "production";
								dump_dir = "/var/lib/meilisearch/${instance.name}/dumps";
								log_level = "info";
								max_indexing_memory = 1Gb;
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
