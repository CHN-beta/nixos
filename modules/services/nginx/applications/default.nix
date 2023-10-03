inputs:
{
  imports = inputs.localLib.mkModules
  [
    ./misskey.nix
    ./synapse.nix
    ./vaultwarden.nix
  ];
}
