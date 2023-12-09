inputs:
{
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.config.nixos) users;
    in mkIf (builtins.elem "yxy" users.users)
    {
      users.users.yxy =
      {
        extraGroups = inputs.lib.intersectLists
          [ "groupshare" "video" ]
          (builtins.attrNames inputs.config.users.groups);
        hashedPasswordFile = inputs.config.sops.secrets."users/yxy".path;
        openssh.authorizedKeys.keys = [ (builtins.readFile ./id_rsa.pub) ];
        shell = inputs.pkgs.zsh;
        autoSubUidGidRange = true;
      };
      home-manager.users.yxy.imports = users.sharedModules;
      sops.secrets."users/yxy".neededForUsers = true;
      nixos.services.groupshare.mountPoints = [ "/home/yxy/groupshare" ];
    };
}
