inputs:
{
  options.nixos.services.postgresql = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = inputs.config.nixos.services.postgresql.instances != {}; };
    instances = mkOption
    {
      type = types.attrsOf (types.submodule (submoduleInputs: { options =
      {
        database = mkOption { type = types.nonEmptyStr; default = submoduleInputs.config._module.args.name; };
        user = mkOption { type = types.nonEmptyStr; default = submoduleInputs.config._module.args.name; };
        passwordFile = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
        initializeFlags = mkOption { type = types.attrsOf types.nonEmptyStr; default = {}; };
      };}));
      default = {};
    };
  };
  config = let inherit (inputs.config.nixos.services) postgresql; in inputs.lib.mkIf postgresql.enable
  {
    services =
    {
      postgresql =
      {
        enable = true;
        package = inputs.pkgs.postgresql_15;
        enableTCPIP = true;
        authentication = "host all all 0.0.0.0/0 md5";
        settings =
        {
          unix_socket_permissions = "0700";
          shared_buffers = "8192MB";
          work_mem = "512MB";
          autovacuum = "on";
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
        ensureUsers = builtins.map (db: { name = db.value.user; }) (inputs.localLib.attrsToList postgresql.instances);
      };
      postgresqlBackup =
      {
        enable = true;
        pgdumpOptions = "-Fc";
        compression = "none";
        databases = builtins.map (db: db.value.database) (inputs.localLib.attrsToList postgresql.instances);
      };
    };
    systemd.services.postgresql.postStart = inputs.lib.mkAfter (builtins.concatStringsSep "\n" (builtins.map
      (db:
        let
          passwordFile =
            if db.value.passwordFile or null != null then db.value.passwordFile
            else inputs.config.sops.secrets."postgresql/${db.value.user}".path;
          initializeFlag =
            if db.value.initializeFlags != {} then
              " WITH "
              + (builtins.concatStringsSep " " (map
                (flag: ''${flag.name} = "${flag.value}"'')
                (inputs.localLib.attrsToList db.value.initializeFlags)))
            else "";
        in
        # create database if not exist
        "$PSQL -tAc \"SELECT 1 FROM pg_database WHERE datname = '${db.value.database}'\" | grep -q 1"
          + " || $PSQL -tAc 'CREATE DATABASE \"${db.value.database}\"${initializeFlag}'"
        # set user password
          + "\n"
          + "$PSQL -tAc \"ALTER USER ${db.value.user} with encrypted password '$(cat ${passwordFile})'\""
        # set db owner
          + "\n"
          + "$PSQL -tAc \"select pg_catalog.pg_get_userbyid(d.datdba) FROM pg_catalog.pg_database d"
          + " WHERE d.datname = '${db.value.database}' ORDER BY 1\""
          + " | grep -E '^${db.value.user}$' -q"
          + " || $PSQL -tAc \"ALTER DATABASE ${db.value.database} OWNER TO ${db.value.user}\"")
      (inputs.localLib.attrsToList postgresql.instances)));
    sops.secrets = builtins.listToAttrs (builtins.map
      (db: { name = "postgresql/${db.value.user}"; value.owner = inputs.config.users.users.postgres.name; })
      (builtins.filter (db: db.value.passwordFile == null) (inputs.localLib.attrsToList postgresql.instances)));
    environment.persistence =
      let inherit (inputs.config.nixos.system) impermanence; in inputs.lib.mkIf impermanence.enable
      {
        "${impermanence.nodatacow}".directories = let user = "postgres"; in
          [{ directory = "/var/lib/postgresql"; inherit user; group = user; mode = "0750"; }];
      };
  };
}
