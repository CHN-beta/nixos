inputs:
{
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.config.nixos) user;
    in mkIf (builtins.elem "yjq" user.users)
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
      home-manager.users.yjq = homeInputs:
      {
        imports = user.sharedModules;
        config.home.file.groupshare.source = homeInputs.config.lib.file.mkOutOfStoreSymlink "/var/lib/groupshare";
      };
      sops.secrets."users/yjq".neededForUsers = true;
    };
}
