{ lib, config, ... }:
{
  options.nixos.services.nfs =
    let
      inherit (config.nixos.services) nfs;
    in
    {
      # export = accessLimit | { clients, options }
      exports = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.oneOf [
            (lib.types.nonEmptyListOf lib.types.nonEmptyStr)
            (lib.types.submodule {
              options = {
                clients = lib.mkOption {
                  type = lib.types.nonEmptyListOf lib.types.nonEmptyStr;
                };
                options = lib.mkOption {
                  type = lib.types.nonEmptyListOf lib.types.nonEmptyStr;
                  default = [
                    "rw"
                    "no_root_squash"
                    "sync"
                    "no_subtree_check"
                  ]
                  ++ lib.optional nfs.crossmnt "crossmnt";
                };
              };
            })
          ]
        );
        default = { };
      };
      crossmnt = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      nproc = lib.mkOption {
        type = lib.types.ints.positive;
        default = 16;
      };
    };
  config =
    let
      inherit (config.nixos.services) nfs;

    in
    lib.mkIf (nfs.exports != { }) {
      services.nfs.server = {
        enable = true;
        inherit (nfs) nproc;
        exports =
          let
            formatExport =
              path: value:
              let
                clients = if builtins.isList value then value else value.clients;
                opts =
                  if builtins.isList value then
                    [
                      "rw"
                      "no_root_squash"
                      "sync"
                      "no_subtree_check"
                    ]
                    ++ lib.optional nfs.crossmnt "crossmnt"
                  else
                    value.options;
                optStr = builtins.concatStringsSep "," opts;
              in
              "${path} ${builtins.concatStringsSep " " (builtins.map (client: "${client}(${optStr})") clients)}";
          in
          lib.concatLines (lib.mapAttrsToList formatExport nfs.exports);
        extraNfsdConfig = ''
          vers2=n
          vers3=n
          vers4=y
          vers4.1=y
          vers4.2=y
        '';
      };
    };
}
