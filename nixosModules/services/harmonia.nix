{ lib, config, ... }: {
  options.nixos.services.harmonia = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.submodule {
        options = {
          hostname = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "nix-store.chn.moe";
          };
          store = lib.mkOption {
            type = lib.types.nullOr lib.types.nonEmptyStr;
            default = null;
          };
        };
      }
    );
    default = null;
  };
  config =
    let
      inherit (config.nixos.services) harmonia;
    in
    lib.mkIf (harmonia != null) {
      services.harmonia-dev = {
        cache = {
          enable = true;
          signKeyPaths = [ config.nixos.system.sops.secrets."store/signingKey".path ];
          settings = lib.mkMerge [
            { bind = "127.0.0.1:5001"; }
            (lib.mkIf (harmonia.store != null) {
              virtual_nix_store = "/nix/store";
              real_nix_store = "${harmonia.store}/nix/store";
              enable_compression = true;
            })
          ];
        };
        daemon = {
          enable = true;
          dbPath = lib.mkIf (harmonia.store != null) "${harmonia.store}/nix/var/nix/db/db.sqlite";
        };
      };
      nixos = {
        system.sops.secrets."store/signingKey" = { };
        services.nginx.https.${harmonia.hostname}.location."/".proxy.upstream = "http://127.0.0.1:5001";
      };
    };
}
