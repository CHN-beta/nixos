inputs:
{
  options.nixos.services.mariadb = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    instances = mkOption
    {
      type = types.attrsOf (types.submodule (submoduleInputs: { options =
      {
        database = mkOption { type = types.nonEmptyStr; default = submoduleInputs.config._module.args.name; };
        user = mkOption { type = types.nonEmptyStr; default = submoduleInputs.config._module.args.name; };
        passwordFile = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
      };}));
      default = {};
    };
  };
  config =
    let
      inherit (inputs.config.nixos.services) mariadb;
      inherit (inputs.lib) mkAfter mkIf;
      inherit (inputs.localLib) attrsToList;
      inherit (builtins) map listToAttrs concatStringsSep filter;
    in mkIf mariadb.enable
    {
      services =
      {
        mysql =
        {
          enable = true;
          package = inputs.pkgs.mariadb;
          settings.mysqld.skip_name_resolve = true;
          ensureDatabases = map (db: db.value.database) (attrsToList mariadb.instances);
          ensureUsers = map
            (db: { name = db.value.user; ensurePermissions."${db.value.database}.*" = "ALL PRIVILEGES"; })
            (attrsToList mariadb.instances);
        };
        mysqlBackup =
        {
          enable = true;
          singleTransaction = true;
          databases = map (db: db.value.database) (attrsToList mariadb.instances);
        };
      };
      systemd.services.mysql.postStart = mkAfter (concatStringsSep "\n" (map
        (db:
          let
            passwordFile =
              if db.value.passwordFile or null != null then db.value.passwordFile
              else inputs.config.sops.secrets."mariadb/${db.value.user}".path;
            mysql = "${inputs.config.services.mysql.package}/bin/mysql";
          in
            # force user use password auth
            ''echo "ALTER USER '${db.value.user}' IDENTIFIED BY '$(cat ${passwordFile})';" | ${mysql} -N'')
        (attrsToList mariadb.instances)));
      sops.secrets = listToAttrs (map
        (db: { name = "mariadb/${db.value.user}"; value.owner = inputs.config.users.users.mysql.name; })
        (filter (db: db.value.passwordFile == null) (attrsToList mariadb.instances)));
    };
}
