inputs:
{
  options.nixos.services.huginn = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
  };
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.config.nixos.services) huginn;
      inherit (builtins) listToAttrs;
    in mkIf huginn.enable
    {
      nixos.services =
      {
        docker.huginn =
        {
          image = inputs.pkgs.dockerTools.pullImage
          {
            imageName = "huginn/huginn";
            imageDigest = "sha256:dbe871597d43232add81d1adfc5ad9f5cf9dcb5e1f1ba3d669598c20b96ab6c1";
            sha256 = "sha256-P8bfzjW5gHCVv0kaEAi9xAe5c0aQXypJkYUfFtE8SVM=";
            finalImageName = "huginn/huginn";
            finalImageTag = "2d5fcafc507da3e8c115c3479e9116a0758c5375";
          };
          ports = [ 3000 ];
          environmentFile = true;
        };
        postgresql = { enable = true; instances.huginn = {}; };
      };
      sops =
      {
        templates."huginn.env" =
        {
          content = let placeholder = inputs.config.sops.placeholder; in
          ''
            MYSQL_PORT_3306_TCP_ADDR=host.docker.internal
            HUGINN_DATABASE_NAME=huginn
            HUGINN_DATABASE_USERNAME=huginn
            HUGINN_DATABASE_PASSWORD=${placeholder."postgresql/huginn"}
            DOMAIN=huginn.chn.moe
            RAILS_ENV=production
            FORCE_SSL=true
            INVITATION_CODE=${placeholder."huginn/invitation_code"}
            SMTP_DOMAIN=mail.chn.moe
            SMTP_USER_NAME=bot@chn.moe
            SMTP_PASSWORD="${placeholder."mail/bot"}"
            SMTP_SERVER=mail.chn.moe
            SMTP_SSL=true
            EMAIL_FROM_ADDRESS=bot@chn.moe
            TIMEZONE=Beijing
          '';
          owner = inputs.config.users.users.huginn.name;
        };
        secrets = listToAttrs (map (secret: { name = secret; value = {}; }) [ "huginn/invitation_code" "mail/bot" ]);
      };
    };
}
