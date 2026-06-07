{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.nixos.services.nginx.applications.nekomia = lib.mkOption {
    type = lib.types.nullOr (lib.types.submodule { });
    default = null;
  };
  config =
    let
      inherit (config.nixos.services.nginx.applications) nekomia;
    in
    lib.mkIf (nekomia != null) {
      nixos.services.nginx.https."nekomia.moe".location."/".static = {
        root =
          let
            drv =
              let
                pandoc = "${pkgs.pandoc}/bin/pandoc";
              in
              pkgs.runCommand "build" { } ''
                mkdir -p $out
                ${pandoc} -f markdown -t html5 -o $out/index.html ${./index.md}
              '';
          in
          "${drv}";
        index = [ "index.html" ];
        charset = "utf-8";
      };
    };
}
