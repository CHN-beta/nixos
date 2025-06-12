inputs:
{
  options.nixos.services.nfs = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.attrsOf (types.nonEmptyListOf types.nonEmptyStr); default = {}; }; # export = accessLimit
  config = let inherit (inputs.config.nixos.services) nfs; in inputs.lib.mkIf (nfs != {})
  {
    services.nfs.server =
    {
      enable = true;
      exports =
        let clientString = clients: builtins.concatStringsSep " " (builtins.map
          (client: "${client}(rw,no_root_squash,sync,crossmnt)") clients);
        in inputs.lib.concatLines (inputs.lib.mapAttrsToList (n: v: "${n} ${clientString v}") nfs);
    };
  };
}
