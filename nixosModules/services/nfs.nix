{ lib, config, ... }:
{
  options.nixos.services.nfs = {
    # export = accessLimit
    exports = lib.mkOption {
      type = lib.types.attrsOf (lib.types.nonEmptyListOf lib.types.nonEmptyStr);
      default = { };
    };
    crossmnt = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };
  config =
    let
      inherit (config.nixos.services) nfs;
    in
    lib.mkIf (nfs.exports != { }) {
      services.nfs.server = {
        enable = true;
        exports =
          let
            clientString =
              clients:
              builtins.concatStringsSep " " (
                builtins.map (
                  client: "${client}(rw,no_root_squash,sync${lib.optionalString nfs.crossmnt ",crossmnt"})"
                ) clients
              );
          in
          lib.concatLines (lib.mapAttrsToList (n: v: "${n} ${clientString v}") nfs.exports);
      };
    };
}
