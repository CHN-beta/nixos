{ lib, config, pkgs, ... }:
{
  options.nixos.services.postgresql =
  {
    instances = lib.mkOption
    {
      type = lib.types.attrsOf (lib.types.submodule (submoduleInputs: { options =
      {
        initializeFlags = lib.mkOption { type = lib.types.attrsOf lib.types.nonEmptyStr; default = {}; };
      };}));
      default = {};
    };
    mountFrom = lib.mkOption { type = lib.types.nullOr lib.types.nonEmptyStr; default = null; };
  };
  config = let inherit (config.nixos.services) postgresql; in lib.mkIf (postgresql.instances != {})
  {
    services =
    {
      postgresql =
      {
        enable = true;
        package = pkgs.postgresql_17;
        extensions = ps: with ps; [ pgroonga ];
        enableTCPIP = true;
        authentication = "host all all 0.0.0.0/0 md5";
        settings =
        {
          unix_socket_permissions = "0700";
          shared_buffers = "512MB";
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
        ensureUsers = postgresql.instances |> lib.mapAttrsToList (n: v: { name = n; });
      };
      postgresqlBackup =
      {
        enable = postgresql.mountFrom != null;
        pgdumpOptions = "-Fc";
        compression = "none";
        databases = postgresql.instances |> lib.mapAttrsToList (n: v: n);
      };
    };
    systemd.services.postgresql-setup.script = postgresql.instances
      |> lib.mapAttrsToList (n: v:
        let
          passwordFile = config.nixos.system.sops.secrets."postgresql/${n}".path;
          initializeFlag = lib.optionalString (v.initializeFlags != {}) (v.initializeFlags
            |> lib.mapAttrsToList (n: v: ''${n} = "${v}"'')
            |> builtins.concatStringsSep " "
            |> (s: " WITH ${s}"));
        in
        ''
          # create database if not exist
          psql -tAc "SELECT 1 FROM pg_database WHERE datname = '${n}'" | grep -q 1 \
            || psql -tAc 'CREATE DATABASE "${n}"${initializeFlag}'
          # set user password
          psql -tAc "ALTER USER ${n} with encrypted password '$(cat ${passwordFile})'"
          # set db owner
          psql -tAc "select pg_catalog.pg_get_userbyid(d.datdba) FROM pg_catalog.pg_database \
              d WHERE d.datname = '${n}' ORDER BY 1" \
            | grep -E '^${n}$' -q \
            || psql -tAc "ALTER DATABASE ${n} OWNER TO ${n}"
        '')
      |> builtins.concatStringsSep "\n"
      |> lib.mkAfter;
    nixos.system.sops.secrets = postgresql.instances
      |> lib.mapAttrs' (n: v: lib.nameValuePair "postgresql/${n}" { owner = "postgres"; });
    environment.persistence = lib.mkIf (postgresql.mountFrom != null)
    {
      "/nix/${postgresql.mountFrom}".directories =
        [{ directory = "/var/lib/postgresql"; user = "postgres"; group = "postgres"; mode = "0750"; }];
    };
  };
}
