inputs: {
  options.nixos.services.httpua =
    let
      inherit (inputs.lib) mkOption types;
    in
    mkOption {
      type = types.nullOr (
        types.submodule {
          options = {
            hostname = mkOption {
              type = types.nonEmptyStr;
              default = "ua.chn.moe";
            };
          };
        }
      );
      default = null;
    };
  config =
    let
      inherit (inputs.config.nixos.services) httpua;
    in
    inputs.lib.mkIf (httpua != null) {
      nixos.services = {
        phpfpm.instances.httpua = { };
        nginx.http.${httpua.hostname}.php = {
          root = builtins.toString (
            inputs.pkgs.writeTextDir "index.php" "<?php echo $_SERVER['HTTP_USER_AGENT']; ?>"
          );
          fastcgiPass = inputs.config.nixos.services.phpfpm.instances.httpua.fastcgi;
        };
      };
    };
}
