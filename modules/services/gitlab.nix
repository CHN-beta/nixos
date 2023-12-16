inputs:
{
  options.nixos.services.gitlab = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    hostname = mkOption { type = types.str; default = "git.chn.moe"; };
  };
  config =
    let
      inherit (inputs.config.nixos.services) gitlab;
      inherit (inputs.lib) mkIf;
    in mkIf gitlab.enable
    {
      services.gitlab =
      {
        enable = true;
        host = gitlab.hostname;
        port = 443;
        https = true;
        smtp =
        {
          enable = true;
          address = "mail.chn.moe";
          username = "bot@chn.moe";
          passwordFile = inputs.config.sops.secrets."gitlab/mail".path;
          tls = true;
          enableStartTLSAuto = false;
          port = 465;
          domain = gitlab.hostname;
          authentication = "login";
        };
        extraConfig =
        {
          gitlab.email_from = "bot@chn.moe";
          lfs.enabled = true;
        };
        secrets =
        {
          secretFile = inputs.config.sops.secrets."gitlab/secret".path;
          otpFile = inputs.config.sops.secrets."gitlab/otp".path;
          jwsFile = inputs.config.sops.secrets."gitlab/jws".path;
          dbFile = inputs.config.sops.secrets."gitlab/dbFile".path;
        };
        initialRootPasswordFile = inputs.config.sops.secrets."gitlab/root".path;
        initialRootEmail = "bot@chn.moe";
        databasePasswordFile = inputs.config.sops.secrets."gitlab/db".path;
        databaseHost = "127.0.0.1";
        extraGitlabRb =
        ''
          gitlab_sshd['enable'] = true
          gitlab_sshd['listen_address'] = '0.0.0.0:2222'
        '';
      };
      nixos.services =
      {
        nginx =
        {
          enable = true;
          https."${gitlab.hostname}".location."/".proxy.upstream = "http://unix:/run/gitlab/gitlab-workhorse.socket";
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
          sopsFile =
            "${inputs.topInputs.self}/secrets/${inputs.config.nixos.system.networking.hostname}/gitlab/jws.bin";
          format = "binary";
        };
        "gitlab/dbFile".owner = owner;
        "gitlab/root".owner = owner;
        "gitlab/db" = { owner = owner; key = "postgresql/gitlab"; };
        "mail/bot" = {};
      };
    };
}
