inputs:
{
  options.nixos.services.nfs = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule { options =
    {
      root = mkOption { type = types.nonEmptyStr; };
      exports = mkOption { type = types.listOf types.nonEmptyStr; };
      accessLimit = mkOption { type = types.nonEmptyStr; };
    };});
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) nfs; in inputs.lib.mkIf (nfs != null)
  {
    services =
    {
      rpcbind.enable = true;
      nfs.server =
      {
        enable = true;
        exports = "${nfs.root} ${nfs.accessLimit}(rw,no_root_squash,fsid=0,sync,crossmnt)"
          + builtins.concatStringsSep "\n" (builtins.map
            (export: "${export} ${nfs.accessLimit}(rw,no_root_squash,sync,crossmnt)")
            nfs.exports);
      };
    };
    networking.firewall.allowedTCPPorts = [ 2049 ];
  };
}
