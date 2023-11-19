inputs:
{
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.config.nixos) users;
    in mkIf (builtins.elem "xll" users.users)
    {
      users.users.xll =
      {
        isNormalUser = true;
        extraGroups = inputs.lib.intersectLists
          [ "groupshare" "video" ]
          (builtins.attrNames inputs.config.users.groups);
        passwordFile = inputs.config.sops.secrets."users/xll".path;
        openssh.authorizedKeys.keys = [ (builtins.readFile ./id_rsa.pub) ];
        shell = inputs.pkgs.zsh;
        autoSubUidGidRange = true;
      };
      home-manager.users.xll.imports = users.sharedModules;
      sops.secrets."users/xll".neededForUsers = true;
      nixos.services.groupshare.mountPoints = [ "/home/xll/groupshare" ];
    };
}
