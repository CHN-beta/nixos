inputs:
{
  options.nixos.virtualization = let inherit (inputs.lib) mkOption types; in
  {
    nspawn = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
  };
  config = inputs.lib.mkMerge
  [
    # nspawn
    {
      systemd.nspawn = builtins.listToAttrs (builtins.map
        (name: { inherit name; value = { execConfig.PrivateUsers = false; networkConfig.VirtualEthernet = false; }; }) 
        inputs.config.nixos.virtualization.nspawn);
    }
  ];
}
