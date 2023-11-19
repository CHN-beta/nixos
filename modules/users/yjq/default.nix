inputs:
{
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.config.nixos) users;
    in mkIf (builtins.elem "yjq" users.users)
    {
      users.users.yjq =
      {
        isNormalUser = true;
        extraGroups = inputs.lib.intersectLists
          [ "groupshare" "video" ]
          (builtins.attrNames inputs.config.users.groups);
        passwordFile = inputs.config.sops.secrets."users/yjq".path;
        openssh.authorizedKeys.keys = [ (builtins.readFile ./id_rsa.pub) ];
        shell = inputs.pkgs.zsh;
        autoSubUidGidRange = true;
      };
      home-manager.users.yjq.imports = users.sharedModules;
      sops.secrets."users/yjq".neededForUsers = true;
      nixos.services.groupshare.mountPoints = [ "/home/yjq/groupshare" ];
    };
}
