{ lib, config, ... }:
{
  options.nixos.services.readeck = lib.mkOption
  {
    type = lib.types.nullOr (lib.types.submodule { options =
    {
      hostname = lib.mkOption { type = lib.types.str; default = "readeck.chn.moe"; };
    };});
    default = null;
  };
  config = let inherit (config.nixos.services) readeck; in lib.mkIf (readeck != null)
  {
    services.readeck =
    {
      enable = true;
      settings =
      {
        server.port = 6778;
        email =
        {
          host = "mail.chn.moe";
          port = 465;
          username = "bot@chn.moe";
          encryption = "ssltls";
          from = "bot@chn.moe";
          from_noreply = "bot@chn.moe";
        };
        extractor.workers = 4;
      };
      environmentFile = config.nixos.system.sops.templates."readeck.env".path;
    };
    nixos =
    {
      system.sops =
      {
        templates."readeck.env".content = let inherit (config.nixos.system.sops) placeholder; in
        ''
          READECK_SECRET_KEY=${placeholder."readeck/secret_key"}
          READECK_DATABASE_SOURCE=postgres://readeck:${placeholder."postgresql/readeck"}@127.0.0.1:5432/readeck"
          READECK_MAIL_PASSWORD=${placeholder."mail/bot"}
        '';
        secrets."readeck/secret_key" = {};
      };
      services =
      {
        postgresql.instances.readeck = {};
        nginx.https.${readeck.hostname}.location."/".proxy.upstream = "http://127.0.0.1:6778";
      };
    };
  };
}
