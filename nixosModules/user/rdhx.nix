{ lib, config, ... }:
{
  config = lib.mkIf (builtins.elem "rdhx" config.nixos.user.users) {
    users.users.rdhx.openssh.authorizedKeys.keys = [ (builtins.readFile ./keys/rdhx) ];
    home-manager.users.rdhx = homeInputs: {
      config.home.file = {
        ".ssh/id_ed25519".source =
          homeInputs.config.lib.file.mkOutOfStoreSymlink
            config.nixos.system.sops.secrets."rdhx/ssh".path;
        ".ssh/id_ed25519.pub".source = ./keys/rdhx;
      };
    };
    nixos.system.sops.secrets."rdhx/ssh" = {
      group = "rdhx";
      mode = "0400";
    };
  };
}
