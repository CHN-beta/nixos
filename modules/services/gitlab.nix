inputs:
{
  options.nixos.services.gitlab = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    hostname = mkOption { type = types.str; default = "gitlab.chn.moe"; };
    # TODO: use redis with TCP and password
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
          dbFile = inputs.config.sops.secrets."gitlab/dbFile".path;
        };
        initialRootPasswordFile = inputs.config.sops.secrets."gitlab/root".path;
        initialRootEmail = "chn@chn.moe";
        databasePasswordFile = inputs.config.sops.secrets."gitlab/db".path;
        databaseHost = "127.0.0.1";
      };
      nixos.services =
      {
        nginx =
        {
          enable = true;
          https."${gitlab.hostname}".location."/".proxy.upstream =
            "http://127.0.0.1:${toString inputs.config.services.gitlab.port}";
        };
        postgresql.instances.gitlab = {};
      };
      sops.secrets = let owner = inputs.config.services.gitlab.user; in
      {
        "gitlab/mail" = { owner = owner; key = "mail/bot"; };
        "gitlab/secret".owner = owner;
        "gitlab/otp".owner = owner;
        "gitlab/jws" =
        {
          owner = owner;
          sopsFile = "${inputs.topInputs.self}/secrets/gitlab/jws.bin";
          format = "binary";
        };
        "gitlab/dbFile".owner = owner;
        "gitlab/root".owner = owner;
        "gitlab/db" = { owner = owner; key = "postgresql/gitlab"; };
        "mail/bot" = {};
      };
    };
}
