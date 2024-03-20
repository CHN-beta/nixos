inputs:
{
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.config.nixos) user;
    in mkIf (builtins.elem "gb" user.users)
    {
      users.users.gb =
      {
        extraGroups = inputs.lib.intersectLists
          [ "groupshare" ]
          (builtins.attrNames inputs.config.users.groups);
        hashedPasswordFile = inputs.config.sops.secrets."users/gb".path;
      };
      home-manager.users.gb = homeInputs:
      {
        config.home.file.groupshare.source = homeInputs.config.lib.file.mkOutOfStoreSymlink "/var/lib/groupshare";
      };
      sops.secrets."users/gb".neededForUsers = true;
    };
}
