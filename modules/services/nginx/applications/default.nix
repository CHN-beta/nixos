inputs:
{
  imports = inputs.localLib.mkModules
  [
    ./vaultwarden.nix
    ./element.nix
    ./synapse-admin.nix
  ];
}
