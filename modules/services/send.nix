inputs:
{
  options.nixos.services.send = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule (submoduleInputs: { options =
    {
      hostname = mkOption { type = types.nonEmptyStr; default = "send.chn.moe"; };
    };}));
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) send; in inputs.lib.mkIf (send != null)
  {
    services.send =
    {
      enable = true;
      baseUrl = "https://${send.hostname}";
      environment.MAX_FILE_SIZE = "17179869184";
      redis =
      {
        createLocally = false;
        host = "127.0.0.1";
        port = 9184;
        passwordFile = inputs.config.sops.secrets."redis/send".path;
      };
    };
    systemd.services.send.after = [ "redis-send.service" ];
    nixos.services =
    {
      nginx =
      {
        enable = true;
        https."${send.hostname}".location."/".proxy = { upstream = "http://127.0.0.1:1443"; websocket = true; };
      };
      redis.instances.send = { user = "root"; port = 9184; };
    };
  };
}
