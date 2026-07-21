{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.nixos.services.postgresql = {
    instances = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (submoduleInputs: {
          options = {
            initializeFlags = lib.mkOption {
              type = lib.types.attrsOf lib.types.nonEmptyStr;
              default = { };
            };
            extensions = lib.mkOption {
              type = lib.types.listOf lib.types.nonEmptyStr;
              default = [ ];
            };
          };
        })
      );
      default = { };
    };
    mountFrom = lib.mkOption {
      type = lib.types.nullOr lib.types.nonEmptyStr;
      default = null;
    };
  };
  config =
    let
      inherit (config.nixos.services) postgresql;
    in
    lib.mkIf (postgresql.instances != { }) {
      services.postgresql = {
        enable = true;
        package = pkgs.postgresql_17;
        extensions =
          ps: with ps; [
            pgroonga
            pgvector
          ];
        enableTCPIP = true;
        authentication = ''
          host all all 0.0.0.0/0 md5
          host all all ::/0 md5
        '';
        settings = {
          unix_socket_permissions = "0700";
          autovacuum = "on";
          shared_buffers = "4GB"; 
          maintenance_work_mem = "2GB";
          work_mem = "64MB"; 
          effective_cache_size = "12GB"; 
          random_page_cost = "1.1";
          max_wal_size = "4GB";
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
      systemd.services.postgresql-setup.script =
        postgresql.instances
        |> lib.mapAttrsToList (
          n: v:
          let
            passwordFile = config.nixos.system.sops.secrets."postgresql/${n}".path;
            initializeFlag = lib.optionalString (v.initializeFlags != { }) (
              v.initializeFlags
              |> lib.mapAttrsToList (n: v: ''${n} = "${v}"'')
              |> builtins.concatStringsSep " "
              |> (s: " WITH ${s}")
            );
          in
          ''
            # create database if not exist
            psql -tAc "SELECT 1 FROM pg_database WHERE datname = '${n}'" | grep -q 1 \
              || psql -tAc 'CREATE DATABASE "${n}"${initializeFlag}'
            # set user password
            psql -tAc "ALTER USER \"${n}\" with encrypted password '$(cat ${passwordFile})'"
            # set db owner
            psql -tAc "select pg_catalog.pg_get_userbyid(d.datdba) FROM pg_catalog.pg_database \
                d WHERE d.datname = '${n}' ORDER BY 1" \
              | grep -E '^${n}$' -q \
              || psql -tAc "ALTER DATABASE \"${n}\" OWNER TO \"${n}\""
            # create extensions
            ${lib.concatMapStringsSep "\n" (ext: ''
              psql -d "${n}" -tAc 'CREATE EXTENSION IF NOT EXISTS "${ext}"'
            '') v.extensions}
          ''
        )
        |> builtins.concatStringsSep "\n"
        |> lib.mkAfter;
      nixos.system.sops.secrets =
        postgresql.instances
        |> lib.mapAttrs' (n: v: lib.nameValuePair "postgresql/${n}" { owner = "postgres"; });
      environment.persistence = lib.mkIf (postgresql.mountFrom != null) {
        "/nix/${postgresql.mountFrom}".directories = [
          {
            directory = "/var/lib/postgresql";
            user = "postgres";
            group = "postgres";
            mode = "0750";
          }
        ];
      };
    };
}
