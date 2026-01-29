{ lib, config, ... }:
{
  config = lib.mkIf ((builtins.elem "chn" config.nixos.user.users) && config.nixos.model.private)
  {
    home-manager.users.chn = homeInputs:
    {
      config.xdg.configFile."sops/age/keys.txt".source =
        homeInputs.config.lib.file.mkOutOfStoreSymlink config.nixos.system.sops.secrets."chn/age".path;
    };
    nixos.system.sops.secrets."chn/age".owner = "chn";
  };
}
