inputs:
{
	options.nixos.services.postgresql = let inherit (inputs.lib) mkOption types; in
	{
		enable = mkOption { type = types.bool; default = false; };
		instances = mkOption
		{
			type = types.listOf (types.oneOf
			[
				types.nonEmptyStr
				(types.submodule (submoduleInputs: { options =
				{
					database = mkOption { type = types.nonEmptyStr; };
					user = mkOption { type = types.nonEmptyStr; default = submoduleInputs.config.database; };
					passwordFile = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
				};}))
			]);
			default = [];
		};
	};
	config =
		let
			inherit (inputs.config.nixos.services) postgresql;
			inherit (inputs.lib) mkMerge mkAfter concatStringsSep mkIf;
			inherit (inputs.localLib) stripeTabs;
			inherit (builtins) map listToAttrs filter;
		in mkIf postgresql.enable
		{
			services.postgresql =
			{
				enable = true;
				package = inputs.pkgs.postgresql_15;
				enableTCPIP = true;
				authentication = "host all all 0.0.0.0/0 md5";
				settings =
				{
					unix_socket_permissions = "0700";
					shared_buffers = "2048MB";
					work_mem = "128MB";
				};
				# log_timezone = 'Asia/Shanghai'
				# datestyle = 'iso, mdy'
				# timezone = 'Asia/Shanghai'
				# lc_messages = 'en_US.utf8'
				# lc_monetary = 'en_US.utf8'
				# lc_numeric = 'en_US.utf8'
				# lc_time = 'en_US.utf8'
				# default_text_search_config = 'pg_catalog.english'
				# plperl.on_init = 'use utf8; use re; package utf8; require "utf8_heavy.pl";'
				# mv /path/to/dir /path/to/dir_old
				# mkdir /path/to/dir
				# chattr +C /path/to/dir
				# cp -a --reflink=never /path/to/dir_old/. /path/to/dir
				# rm -rf /path/to/dir_old
				ensureDatabases = map (db: db.database or db) postgresql.instances;
				ensureUsers = map (db: { name = db.user or db; }) postgresql.instances;
			};
			systemd.services.postgresql.postStart = mkAfter (concatStringsSep "\n" (map
				(db:
					let
						passwordFile =
							if db.passwordFile or null != null then db.passwordFile
							else inputs.config.sops.secrets."postgresql/${db.user or db}".path;
						in
						# set user password
						''$PSQL -tAc "ALTER USER '${db.user or db}' with encrypted password '$(cat ${passwordFile})'"''
						# set db owner
							+ "\n"
							+ ''$PSQL -tAc "select pg_catalog.pg_get_userbyid(d.datdba) FROM pg_catalog.pg_database d''
							+ '' WHERE d.datname = '${db.database ? db}' ORDER BY 1"''
							+ '' | grep -E '^${db.user or db}$' -q''
							+ '' || $PSQL -tAc "ALTER DATABASE '${db.database or db}' OWNER TO '${db.user or db}'"'')
				postgresql.instances));
			sops.secrets = listToAttrs (map
				(db: { name = "postgresql/${db.user or db}"; value.owner = inputs.config.users.users.postgres.name; })
				(filter (db: db.passwordFile or null == null) postgresql.instances));
		};
}
  # sops.secrets.drone-agent = {
  #   owner = config.systemd.services.drone-agent.serviceConfig.User;
  #   key = "drone";
  # };
