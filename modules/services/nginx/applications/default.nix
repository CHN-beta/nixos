inputs:
{
  imports = inputs.localLib.mkModules
  [
    ./misskey.nix
    ./synapse.nix
    ./vaultwarden.nix
    ./element.nix
    ./photoprism.nix
    ./nextcloud.nix
    ./synapse-admin.nix
  ];
}
