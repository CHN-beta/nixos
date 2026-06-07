{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.nixos.services.nginx.applications.blog = lib.mkOption {
    type = lib.types.nullOr (lib.types.submodule { });
    default = null;
  };
  config =
    let
      inherit (config.nixos.services.nginx.applications) blog;
    in
    lib.mkIf (blog != null) {
      nixos.services.nginx.https."blog.chn.moe".location."/".static = {
        root = "${pkgs.localPkgs.blog}";
        index = [ "index.html" ];
      };
    };
}
