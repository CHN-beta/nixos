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
          tls = true;
          port = 465;
          domain = gitlab.hostname;
          username = "bot@chn.moe";
        };
        redisUrl = "redis://127.0.0.1:6379/"
