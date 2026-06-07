{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.nixos.services.nginx.applications.element = lib.mkOption {
    type = lib.types.nullOr (lib.types.submodule { });
    default = null;
  };
  config =
    let
      inherit (config.nixos.services.nginx.applications) element;
    in
    lib.mkIf (element != null) {
      nixos.services.nginx.https."element.chn.moe".location."/".static = {
        root = builtins.toString (
          pkgs.element-web.override {
            conf = {
              default_server_config."m.homeserver" = {
                base_url = "https://element.chn.moe";
                server_name = "element.chn.moe";
              };
              disable_guests = false;
            };
          }
        );
        index = [ "index.html" ];
      };
    };
}
