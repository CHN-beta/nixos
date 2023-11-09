inputs:
{
  imports = inputs.localLib.mkModules
  [
    ./synapse.nix
    ./vaultwarden.nix
    ./element.nix
    ./photoprism.nix
    ./synapse-admin.nix
  ];
}
