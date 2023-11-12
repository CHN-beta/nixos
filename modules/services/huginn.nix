inputs:
{
  options.nixos.services.huginn = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    hostname = mkOption { type = types.str; default = "huginn.chn.moe"; };
  };
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.localLib) attrsToList;
      inherit (inputs.config.nixos.services) huginn;
      inherit (builtins) map listToAttrs toString;
    in mkIf huginn.enable
    {
      virtualisation.oci-containers.containers.huginn =
      {
        image = "huginn/huginn:2d5fcafc507da3e8c115c3479e9116a0758c5375";
        imageFile = inputs.pkgs.dockerTools.pullImage
        {
          imageName = "ghcr.io/huginn/huginn";
          imageDigest = "sha256:aa694519b196485c6c31582dde007859fc8b8bbe9b1d4d94c6db8558843d0458";
          sha256 = "0471v20d7ilwx81kyrxjcb90nnmqyyi9mwazbpy3z4rhnzv7pz76";
          finalImageName = "huginn/huginn";
          finalImageTag = "2d5fcafc507da3e8c115c3479e9116a0758c5375";
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
        # TODO: root docker use config of rootless docker?
        virtualization.docker.enable = true;
      };
    };
}
