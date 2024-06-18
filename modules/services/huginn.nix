inputs:
{
  options.nixos.services.huginn = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    hostname = mkOption { type = types.nonEmptyStr; default = "huginn.chn.moe"; };
  };
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.config.nixos.services) huginn;
    in mkIf huginn.enable
    {
      virtualisation.oci-containers.containers.huginn =
      {
        image = "huginn/huginn:5a1509b51188e0d16868be893c983d6fcfd232a5";
        imageFile = inputs.pkgs.dockerTools.pullImage
        {
          imageName = "ghcr.io/huginn/huginn";
          imageDigest = "sha256:6f7a5b41457b94490210221a8bd3aae32d4ebfc2652f97c14919aa8036d7294e";
          sha256 = "1ha6c6bwdpdl98cwwxw5fan0j77ylgaziidqhnyh6anpzq35f540";
          finalImageName = "huginn/huginn";
          finalImageTag = "5a1509b51188e0d16868be893c983d6fcfd232a5";
        };
        ports = [ "127.0.0.1:3000:3000/tcp" ];
        extraOptions = [ "--add-host=host.docker.internal:host-gateway" ];
        environmentFiles = [ inputs.config.sops.templates."huginn/env".path ];
      };
      sops =
      {
        templates."huginn/env".content = let placeholder = inputs.config.sops.placeholder; in
        ''
          MYSQL_PORT_3306_TCP_ADDR=host.docker.internal
          HUGINN_DATABASE_NAME=huginn
          HUGINN_DATABASE_USERNAME=huginn
          HUGINN_DATABASE_PASSWORD=${placeholder."mariadb/huginn"}
          DOMAIN=${huginn.hostname}
          RAILS_ENV=production
          FORCE_SSL=true
          INVITATION_CODE=${placeholder."huginn/invitationCode"}
          SMTP_DOMAIN=mail.chn.moe
          SMTP_USER_NAME=bot@chn.moe
          SMTP_PASSWORD="${placeholder."mail/bot"}"
          SMTP_SERVER=mail.chn.moe
          SMTP_SSL=true
          EMAIL_FROM_ADDRESS=bot@chn.moe
          TIMEZONE=Beijing
          DO_NOT_CREATE_DATABASE=true
        '';
        secrets = { "huginn/invitationCode" = {}; "mail/bot" = {}; };
      };
      nixos =
      {
        services =
        {
          nginx =
          {
            enable = true;
            https."${huginn.hostname}".location."/".proxy = { upstream = "http://127.0.0.1:3000"; websocket = true; };
          };
          mariadb.instances.huginn = {};
        };
        virtualization.docker.enable = true;
      };
    };
}
