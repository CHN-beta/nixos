{ lib, config, ... }:
{
  config = lib.mkIf (builtins.elem "lcl" config.nixos.user.users) {
    users.users.lcl = {
      extraGroups = lib.intersectLists [ "straycat" ] (builtins.attrNames config.users.groups);
      openssh.authorizedKeys.keys = [ (builtins.readFile ./keys/lcl) ];
    };
    home-manager.users.lcl = homeInputs: {
      config.home.file = {
        ".ssh/id_ed25519".source =
          homeInputs.config.lib.file.mkOutOfStoreSymlink
            config.nixos.system.sops.secrets."lcl/ssh".path;
        ".ssh/id_ed25519.pub".source = ./keys/lcl;
      };
    };
    nixos.system.sops.secrets."lcl/ssh" = {
      group = "lcl";
      mode = "0400";
    };
  };
}
