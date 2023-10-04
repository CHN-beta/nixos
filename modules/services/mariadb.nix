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
      inherit (inputs.lib) mkIf;
      inherit (inputs.localLib) attrsToList;
      inherit (builtins) map listToAttrs filter;
    in mkIf mariadb.enable
    {
      services =
      {
        mysql =
        {
          enable = true;
          package = inputs.pkgs.mariadb;
          ensureDatabases = map (db: db.value.database) (attrsToList mariadb.instances);
          ensureUsers = map (db: { name = db.value.user; }) (attrsToList mariadb.instances);
        };
        mysqlBackup =
        {
          enable = true;
          databases = map (db: db.value.database) (attrsToList mariadb.instances);
        };
      };
      sops.secrets = listToAttrs (map
        (db: { name = "mariadb/${db.value.user}"; value.owner = inputs.config.users.users.mysql.name; })
        (filter (db: db.value.passwordFile == null) (attrsToList mariadb.instances)));
    };
}
