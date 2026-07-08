{
  lib,
  config,
  pkgs,
  self,
  ...
}:
{
  options.nixos.services.nginx.applications.sticker = lib.mkOption {
    type = lib.types.nullOr (lib.types.submodule { });
    default = null;
  };
  config =
    let
      inherit (config.nixos.services.nginx.applications) sticker;
    in
    lib.mkIf (sticker != null) {
      nixos.services.nginx.https."sticker.chn.moe".location."/".static = {
        root = builtins.toString (
          pkgs.runCommand "web" { } ''
            mkdir -p $out
            cp -r ${self.inputs.stickerpicker}/web/* $out
            chmod -R +w $out
            cp -r ${self.inputs.sticker}/web/* $out
          ''
        );
        index = [ "index.html" ];
      };
    };
}
