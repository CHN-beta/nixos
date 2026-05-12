inputs:
{
  options.nixos.services.httpapi = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule { options =
    {
      hostname = mkOption { type = types.nonEmptyStr; default = "api.chn.moe"; };
    };});
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) httpapi; in inputs.lib.mkIf (httpapi != null)
  {
    nixos =
    {
      services =
      {
        phpfpm.instances.httpapi = {};
        nginx.https.${httpapi.hostname}.location =
        {
          "/files".static.root = "/srv/api";
          "/led".static = { root = "/srv/api"; detectAuth.users = [ "led" ]; };
          "/notify.php".php =
          {
            root = builtins.dirOf inputs.config.nixos.system.sops.templates."httpapi/notify.php".path;
            fastcgiPass = inputs.config.nixos.services.phpfpm.instances.httpapi.fastcgi;
          };
        };
      };
      system.sops =
      {
        templates."httpapi/notify.php" =
        {
          owner = inputs.config.users.users.httpapi.name;
          group = inputs.config.users.users.httpapi.group;
          content =
            let
              inherit (inputs.config.sops) placeholder;
              request = "https://api.telegram.org/bot${placeholder."telegram/token"}"
                + "/sendMessage?chat_id=${placeholder."telegram/user/chn"}&text=";
            in ''<?php print file_get_contents("${request}".urlencode($_GET["message"])); ?>'';
        };
        secrets = { "telegram/token" = {}; "telegram/user/chn" = {}; };
      };
    };
    systemd.tmpfiles.rules = [ "d /srv/api 0700 nginx nginx" "Z /srv/api - nginx nginx" ];
  };
}
