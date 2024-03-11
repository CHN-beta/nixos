inputs:
{
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.config.nixos) users;
    in mkIf (builtins.elem "zem" users.users)
    {
      users.users.zem =
      {
        extraGroups = inputs.lib.intersectLists
          [ "users" "groupshare" "video" ]
          (builtins.attrNames inputs.config.users.groups);
        hashedPasswordFile = inputs.config.sops.secrets."users/zem".path;
        openssh.authorizedKeys.keys = [ (builtins.readFile ./id_rsa.pub) ];
        shell = inputs.pkgs.zsh;
        autoSubUidGidRange = true;
      };
      home-manager.users.zem =
      {
        imports = users.sharedModules;
        config.home.file.groupshare.source = inputs.lib.file.mkOutOfStoreSymlink "/var/lib/groupshare";
      };
      sops.secrets."users/zem".neededForUsers = true;
    };
}
