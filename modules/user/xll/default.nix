inputs:
{
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.config.nixos) user;
    in mkIf (builtins.elem "xll" user.users)
    {
      users.users.xll =
      {
        extraGroups = inputs.lib.intersectLists
          [ "groupshare" ]
          (builtins.attrNames inputs.config.users.groups);
        hashedPasswordFile = inputs.config.sops.secrets."users/xll".path;
      };
      home-manager.users.xll = homeInputs:
      {
        config.home.file.groupshare.source = homeInputs.config.lib.file.mkOutOfStoreSymlink "/var/lib/groupshare";
      };
      sops.secrets."users/xll".neededForUsers = true;
    };
}
