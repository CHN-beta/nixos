{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.nixos.services.mariadb = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.nixos.services.mariadb.instances != { };
    };
    instances = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (submoduleInputs: {
          options = {
            database = lib.mkOption {
              type = lib.types.nonEmptyStr;
              default = submoduleInputs.config._module.args.name;
            };
            user = lib.mkOption {
              type = lib.types.nonEmptyStr;
              default = submoduleInputs.config._module.args.name;
            };
            passwordFile = lib.mkOption {
              type = lib.types.nullOr lib.types.nonEmptyStr;
              default = null;
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
      inherit (config.nixos.services) mariadb;
    in
    lib.mkIf mariadb.enable {
      services = {
        mysql = {
          enable = true;
          package = pkgs.mariadb;
          settings.mysqld.skip_name_resolve = true;
          ensureDatabases = map (db: db.value.database) (lib.attrsToList mariadb.instances);
          ensureUsers = map (db: {
            name = db.value.user;
            ensurePermissions."${db.value.database}.*" = "ALL PRIVILEGES";
          }) (lib.attrsToList mariadb.instances);
        };
        mysqlBackup = {
          enable = mariadb.mountFrom != null;
          singleTransaction = true;
          databases = map (db: db.value.database) (lib.attrsToList mariadb.instances);
        };
      };
      systemd.services.mysql.postStart = lib.mkAfter (
        lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            _: db:
            let
              passwordFile =
                if db.passwordFile or null != null then
                  db.passwordFile
                else
                  config.nixos.system.sops.secrets."mariadb/${db.user}".path;
              mysql = "${config.services.mysql.package}/bin/mysql";
            in
            # force user use password auth
            ''echo "ALTER USER '${db.user}' IDENTIFIED BY '$(cat ${passwordFile})';" | ${mysql} -N''
          ) mariadb.instances
        )
      );
      nixos.system.sops.secrets = lib.listToAttrs (
        map (db: {
          name = "mariadb/${db.value.user}";
          value.owner = config.users.users.mysql.name;
        }) (lib.filter (db: db.value.passwordFile == null) (lib.attrsToList mariadb.instances))
      );
      environment.persistence = lib.mkIf (mariadb.mountFrom != null) {
        "/nix/${mariadb.mountFrom}".directories = [
          {
            directory = "/var/lib/mysql";
            user = "mysql";
            group = "mysql";
            mode = "0750";
          }
        ];
      };
    };
}
