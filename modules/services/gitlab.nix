inputs:
{
  options.nixos.services.gitlab = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    hostname = mkOption { type = types.str; default = "gitlab.chn.moe"; };
  };
  config =
    let
      inherit (inputs.config.nixos.services) gitlab;
      inherit (inputs.lib) mkIf;
      inherit (builtins) map listToAttrs toString replaceStrings filter;
    in mkIf gitlab.enable
    {
      services.gitlab =
      {
        enable = true;
        host = gitlab.hostname;
        https = true;
        smtp =
        {
          enable = true;
          username = "bot@chn.moe";
          tls = true;
          port = 465;
          domain = gitlab.hostname;
          passwordFile = inputs.config.sops.secrets."gitlab/mail".path;
          authentication = "login";
        };
        secrets =
        {
          secretFile = inputs.config.sops.secrets."gitlab/secret".path;
          otpFile = inputs.config.sops.secrets."gitlab/otp".path;
          jwsFile = inputs.config.sops.secrets."gitlab/jws".path;
          dbFile = inputs.config.sops.secrets."gitlab/db".path;
        };
        initialRootPasswordFile = inputs.config.sops.secrets."gitlab/root".path;
        initialRootEmail = "chn@chn.moe";
        databasePasswordFile = inputs.config.sops.secrets."gitlab/db".path;
        databaseHost = "127.0.0.1";
        redisUrl = "redis://127.0.0.1:6379/"
