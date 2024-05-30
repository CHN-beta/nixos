inputs:
{
  options.nixos.services.mariadb = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = inputs.nixos.services.mariadb.instances != {}; };
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
  config = let inherit (inputs.config.nixos.services) mariadb; in inputs.lib.mkIf mariadb.enable
  {
    services =
    {
      mysql =
      {
        enable = true;
        package = inputs.pkgs.mariadb;
        settings.mysqld.skip_name_resolve = true;
        ensureDatabases = builtins.map (db: db.value.database) (inputs.localLib.attrsToList mariadb.instances);
        ensureUsers = builtins.map
          (db: { name = db.value.user; ensurePermissions."${db.value.database}.*" = "ALL PRIVILEGES"; })
          (inputs.localLib.attrsToList mariadb.instances);
      };
      mysqlBackup =
      {
        enable = true;
        singleTransaction = true;
        databases = builtins.map (db: db.value.database) (inputs.localLib.attrsToList mariadb.instances);
      };
    };
    systemd.services.mysql.postStart = inputs.lib.mkAfter (builtins.concatStringsSep "\n" (builtins.map
      (db:
        let
          passwordFile =
            if db.value.passwordFile or null != null then db.value.passwordFile
            else inputs.config.sops.secrets."mariadb/${db.value.user}".path;
          mysql = "${inputs.config.services.mysql.package}/bin/mysql";
        in
          # force user use password auth
          ''echo "ALTER USER '${db.value.user}' IDENTIFIED BY '$(cat ${passwordFile})';" | ${mysql} -N'')
      (inputs.localLib.attrsToList mariadb.instances)));
    sops.secrets = builtins.listToAttrs (builtins.map
      (db: { name = "mariadb/${db.value.user}"; value.owner = inputs.config.users.users.mysql.name; })
      (builtins.filter (db: db.value.passwordFile == null) (inputs.localLib.attrsToList mariadb.instances)));
    environment.persistence =
      let inherit (inputs.config.nixos.system) impermanence; in inputs.lib.mkIf impermanence.enable
      {
        "${impermanence.nodatacow}".directories = let user = "mysql"; in
          [{ directory = "/var/lib/mysql"; inherit user; group = user; mode = "0750"; }];
      };
  };
}
