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
        extraGroups = inputs.lib.intersectLists
          [ "users" "groupshare" "video" ]
          (builtins.attrNames inputs.config.users.groups);
        hashedPasswordFile = inputs.config.sops.secrets."users/xll".path;
        openssh.authorizedKeys.keys = [ (builtins.readFile ./id_rsa.pub) ];
        shell = inputs.pkgs.zsh;
        autoSubUidGidRange = true;
      };
      home-manager.users.xll =
      {
        imports = users.sharedModules;
        config.home.file.groupshare.source = inputs.lib.file.mkOutOfStoreSymlink "/var/lib/groupshare";
      };
      sops.secrets."users/xll".neededForUsers = true;
    };
}
