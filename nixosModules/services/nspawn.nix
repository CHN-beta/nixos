{ lib, config, ... }:
{
  options.nixos.services.nspawn = lib.mkOption
    { type = lib.types.listOf lib.types.nonEmptyStr; default = []; };
  config = let inherit (config.nixos.services) nspawn; in
  {
    systemd.nspawn = builtins.listToAttrs (builtins.map
      (name: { inherit name; value = { execConfig.PrivateUsers = false; networkConfig.VirtualEthernet = false; }; }) 
      nspawn);
  };
}
