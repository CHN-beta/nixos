inputs:
{
  imports = inputs.localLib.mkModules
  [
    ./element.nix
    ./synapse-admin.nix
    ./kkmeeting.nix
    ./webdav.nix
    ./blog.nix
    ./catalog.nix
    ./main.nix
  ];
}
