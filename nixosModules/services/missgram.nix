inputs: {
  options.nixos.services.missgram =
    let
      inherit (inputs.lib) mkOption types;
    in
    mkOption {
      type = types.nullOr (types.submodule { });
      default = null;
    };
  config =
    let
      inherit (inputs.config.nixos.services) missgram;
    in
    inputs.lib.mkIf (missgram != null) {
      users = {
        users.missgram = {
          uid = inputs.config.nixos.user.uid.missgram;
          group = "missgram";
          isSystemUser = true;
        };
        groups.missgram.gid = inputs.config.nixos.user.gid.missgram;
      };
      systemd = {
        services.missgram = {
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            User = inputs.config.users.users.missgram.name;
            Group = inputs.config.users.users.missgram.group;
            ExecStart =
              let
                forwarder = inputs.pkgs.localPkgs.missgram.override {
                  configFile = inputs.config.nixos.system.sops.templates."missgram/config.yaml".path;
                };
              in
              "${forwarder}/bin/missgram";
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
                inherit (inputs.config.nixos.system.sops) placeholder;
              in
              builtins.toJSON {
                Secret = placeholder."missgram/secret";
                TelegramBotToken = placeholder."missgram/telegramBotToken";
                TelegramChatId = -1003641252872;
                ServerPort = 9173;
                dbPassword = placeholder."postgresql/missgram";
              };
          };
          secrets = {
            "missgram/secret" = { };
            "missgram/telegramBotToken" = { };
          };
        };
      };
    };
}
