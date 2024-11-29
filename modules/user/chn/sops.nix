inputs:
{
  config = inputs.lib.mkIf
  (
    (builtins.elem "chn" inputs.config.nixos.user.users)
      && (builtins.elem inputs.config.nixos.model.hostname [ "pc" ])
  )
  {
    home-manager.users.chn = homeInputs:
    {
      config.xdg.configFile."sops/age/keys.txt".source =
        homeInputs.config.lib.file.mkOutOfStoreSymlink inputs.config.sops.secrets.age.path;
    };
    sops.secrets.age.owner = "chn";
  };
}
