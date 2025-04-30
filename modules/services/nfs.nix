inputs:
{
  options.nixos.services.nfs = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.attrsOf types.nonEmptyStr; default = {}; }; # export = accessLimit
  config = let inherit (inputs.config.nixos.services) nfs; in inputs.lib.mkIf (nfs != {})
  {
    services =
    {
      rpcbind.enable = true;
      nfs.server =
      {
        enable = true;
        exports = builtins.concatStringsSep "\n" (builtins.map
          (export: "${export.name} ${export.value}(rw,no_root_squash,sync,crossmnt)")
          (inputs.localLib.attrsToList nfs));
      };
    };
    networking.firewall.allowedTCPPorts = [ 2049 ];
  };
}
