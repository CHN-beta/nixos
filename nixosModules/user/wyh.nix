{ lib, config, ... }:
{
  config = lib.mkIf (builtins.elem "wyh" config.nixos.user.users) {
    users.users.wyh = {
      extraGroups = lib.intersectLists [ "straycat" ] (builtins.attrNames config.users.groups);
      openssh.authorizedKeys.keys = [ (builtins.readFile ./keys/wyh) ];
      hashedPassword = "$y$j9T$zhMtkySO1LFe8WNbONkWX.$PHUORbar1/6btxJ89RRiy3W1nvie6rTsicGmqm18pB9";
    };
    home-manager.users.wyh = homeInputs: {
      config.home.file = {
        ".ssh/id_ed25519".source =
          homeInputs.config.lib.file.mkOutOfStoreSymlink
            config.nixos.system.sops.secrets."wyh/ssh".path;
        ".ssh/id_ed25519.pub".source = ./keys/wyh;
      };
    };
    nixos.system.sops.secrets."wyh/ssh" = {
      group = "wyh";
      mode = "0400";
    };
  };
}
