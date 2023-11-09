inputs:
{
  imports = inputs.localLib.mkModules
  [
    ./synapse.nix
    ./vaultwarden.nix
    ./element.nix
    ./photoprism.nix
    ./nextcloud.nix
    ./synapse-admin.nix
  ];
}
