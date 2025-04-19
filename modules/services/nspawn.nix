inputs:
{
  options.nixos.services.nspawn = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.listOf types.nonEmptyStr; default = []; };
  config = let inherit (inputs.config.nixos.services) nspawn; in
  {
    systemd.nspawn = builtins.listToAttrs (builtins.map
      (name: { inherit name; value = { execConfig.PrivateUsers = false; networkConfig.VirtualEthernet = false; }; }) 
      nspawn);
  };
}
