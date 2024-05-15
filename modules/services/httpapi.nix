inputs:
{
  options.nixos.services.httpapi = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    hostname = mkOption { type = types.nonEmptyStr; default = "api.chn.moe"; };
  };
  config =
    let
      inherit (inputs.config.nixos.services) httpapi;
      inherit (inputs.lib) mkIf;
      inherit (builtins) toString map;
    in mkIf httpapi.enable
    {
      nixos.services =
      {
        phpfpm.instances.httpapi = {};
        nginx.https.${httpapi.hostname}.location =
        {
          "/files".static.root = "/srv/api";
          "/led".static = { root = "/srv/api"; detectAuth.users = [ "led" ]; };
          "/notify.php".php =
          {
            root = builtins.dirOf inputs.config.sops.templates."httpapi/notify.php".path;
            fastcgiPass = inputs.config.nixos.services.phpfpm.instances.httpapi.fastcgi;
          };
        };
      };
      sops =
      {
        templates."httpapi/notify.php" =
        {
          owner = inputs.config.users.users.httpapi.name;
          group = inputs.config.users.users.httpapi.group;
          content =
            let
              placeholder = inputs.config.sops.placeholder;
              request = "https://api.telegram.org/${placeholder."telegram/token"}"
                + "/sendMessage?chat_id=${placeholder."telegram/chat"}&text=";
            in ''<?php print file_get_contents("${request}".urlencode($_GET["message"])); ?>'';
        };
        secrets = { "telegram/token" = {}; "telegram/chat" = {}; };
      };
      systemd.tmpfiles.rules = [ "d /srv/api 0700 nginx nginx" "Z /srv/api - nginx nginx" ];
    };
}
