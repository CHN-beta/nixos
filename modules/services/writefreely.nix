inputs:
{
  options.nixos.services.writefreely = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule (submoduleInputs: { options =
    {
      hostname = mkOption { type = types.nonEmptyStr; default = "write.chn.moe"; };
    };}));
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) writefreely; in inputs.lib.mkIf (writefreely != null)
  {
    services.writefreely =
    {
      enable = true;
      settings = { server.port = 7264; app = { host = "https://${writefreely.hostname}"; federation = true; }; };
      host = writefreely.hostname;
      database = { type = "mysql"; passwordFile = inputs.config.sops.secrets."writefreely/mariadb".path; };
      admin = { name = "chn"; initialPasswordFile = inputs.config.sops.secrets."writefreely/chn".path; };
    };
    systemd.services = { writefreely.after = [ "mysql.service" ]; writefreely-mysql-init.after = [ "mysql.service" ]; };
    sops.secrets =
    {
      "writefreely/chn".owner = "writefreely";
      "writefreely/mariadb" = { owner = "writefreely"; key = "mariadb/writefreely"; };
    };
    nixos.services =
    {
      mariadb.instances.writefreely = {};
      nginx =
      {
        enable = true;
        https.${writefreely.hostname}.location."/".proxy.upstream =
          "http://127.0.0.1:${builtins.toString inputs.config.services.writefreely.settings.server.port}";
      };
    };
  };
}
