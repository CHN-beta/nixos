{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.nixos.services.ananicy = lib.mkOption {
    type = lib.types.nullOr (lib.types.submodule { });
    default = null;
  };
  config =
    let
      inherit (config.nixos.services) ananicy;
    in
    lib.mkIf (ananicy != null) {
      services.ananicy = {
        enable = true;
        package = pkgs.ananicy-cpp;
        rulesProvider = pkgs.ananicy-rules-cachyos;
        extraRules = [
          {
            name = "YuanShen.exe";
            type = "Game";
          }
          {
            name = "Typora";
            type = "Doc-View";
          }
        ];
      };
    };
}
