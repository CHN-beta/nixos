{ lib, config, ... }:
{
  options.nixos.model = {
    hostname = lib.mkOption { type = lib.types.nonEmptyStr; };
    arch = lib.mkOption {
      type = lib.types.nonEmptyStr;
      default = "x86_64";
    };
    variant = lib.mkOption {
      type = lib.types.enum [
        "minimal"
        "desktop"
        "server"
      ];
      default = "minimal";
    };
    private = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    cluster = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.submodule {
          options = {
            clusterName = lib.mkOption { type = lib.types.nonEmptyStr; };
            nodeName = lib.mkOption { type = lib.types.nonEmptyStr; };
            nodeType = lib.mkOption {
              type = lib.types.enum [
                "master"
                "worker"
              ];
              default = "worker";
            };
          };
        }
      );
      default = null;
    };
  };
  config =
    let
      inherit (config.nixos) model;
    in
    lib.mkMerge [
      { networking.hostName = model.hostname; }
      (lib.mkIf (model.cluster != null) {
        nixos.model.hostname = "${model.cluster.clusterName}-${model.cluster.nodeName}";
      })
    ];
}
