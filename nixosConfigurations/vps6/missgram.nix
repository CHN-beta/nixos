{
  pkgs,
  lib,
  config,
  ...
}:
{
  config = {
    users = {
      users.missgram = {
        uid = config.nixos.user.uid.missgram;
        group = "missgram";
        isSystemUser = true;
      };
      groups.missgram.gid = config.nixos.user.gid.missgram;
    };
    systemd = {
      services.missgram = {
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          User = config.users.users.missgram.name;
          Group = config.users.users.missgram.group;
          ExecStart = "${lib.getExe pkgs.localPkgs.missgram} --config ${
            config.nixos.system.sops.templates."missgram/config.yaml".path
          }";
        };
      };
    };
    nixos = {
      services = {
        nginx.https."missgram.chn.moe".location."/".proxy.upstream = "http://127.0.0.1:9173";
        postgresql.instances.missgram = { };
      };
      system.sops = {
        templates."missgram/config.yaml" = {
          owner = "missgram";
          content =
            let
              inherit (config.nixos.system.sops) placeholder;
            in
            builtins.toJSON {
              secret = placeholder."missgram/secret";
              telegram_bot_token = placeholder."missgram/telegramBotToken";
              telegram_chat_id = -1003641252872;
              server_port = 9173;
              db_password = placeholder."postgresql/missgram";
              twitter_api_key = placeholder."missgram/twitter_api_key";
              twitter_api_secret = placeholder."missgram/twitter_api_secret";
              twitter_access_token = placeholder."missgram/twitter_access_token";
              twitter_access_token_secret = placeholder."missgram/twitter_access_token_secret";
            };
        };
        secrets = {
          "missgram/secret" = { };
          "missgram/telegramBotToken" = { };
          "missgram/twitter_api_key" = { };
          "missgram/twitter_api_secret" = { };
          "missgram/twitter_access_token" = { };
          "missgram/twitter_access_token_secret" = { };
        };
      };
    };
  };
}
