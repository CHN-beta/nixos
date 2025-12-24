inputs:
{
  options.nixos.services.misskey-forwarder = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.services) misskey-forwarder; in inputs.lib.mkIf (misskey-forwarder != null)
  {
    users =
    {
      users.misskey-forwarder =
        { uid = inputs.config.nixos.user.uid.misskey-forwarder; group = "misskey-forwarder"; isSystemUser = true; };
      groups.misskey-forwarder.gid = inputs.config.nixos.user.gid.misskey-forwarder;
    };
    systemd =
    {
      services.misskey-forwarder =
      {
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig =
        {
          User = inputs.config.users.users.misskey-forwarder.name;
          Group = inputs.config.users.users.misskey-forwarder.group;
          ExecStart =
            let forwarder = inputs.pkgs.localPackages.misskey-forwarder.override
              { configFile = inputs.config.nixos.system.sops.templates."misskey-forwarder/config.yml".path; };
            in "${forwarder}/bin/misskey-forwarder";
        };
      };
    };
    nixos =
    {
      services.nginx.https."misskey-forwarder.chn.moe".location."/".proxy.upstream = "http://127.0.0.1:9173";
      system.sops =
      {
        templates."misskey-forwarder/config.yml" =
        {
          owner = "misskey-forwarder";
          content =
            let inherit (inputs.config.nixos.system.sops) placeholder;
            in builtins.toJSON
            {
              Secret = placeholder."misskey-forwarder/secret";
              TelegramBotToken = placeholder."misskey-forwarder/telegramBotToken";
              TelegramChatId = placeholder."misskey-forwarder/telegramChatId";
              ServerPort = 9173;
            };
        };
        secrets = inputs.lib.genAttrs' [ "secret" "telegramBotToken" "telegramChatId" ]
          (n: inputs.lib.nameValuePair "misskey-forwarder/${n}" {});
      };
    };
  };
}
