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
        extraGroups = inputs.lib.intersectLists
          [ "users" "groupshare" "video" ]
          (builtins.attrNames inputs.config.users.groups);
        hashedPasswordFile = inputs.config.sops.secrets."users/yjq".path;
        openssh.authorizedKeys.keys = [ (builtins.readFile ./id_rsa.pub) ];
        shell = inputs.pkgs.zsh;
        autoSubUidGidRange = true;
      };
      home-manager.users.yjq =
      {
        imports = users.sharedModules;
        config.home.file.groupshare.source = inputs.lib.file.mkOutOfStoreSymlink "/var/lib/groupshare";
      };
      sops.secrets."users/yjq".neededForUsers = true;
    };
}
