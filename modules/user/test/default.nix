inputs:
{
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.config.nixos) user;
    in mkIf (builtins.elem "test" user.users)
    {
      users.users.test =
      {
        extraGroups = inputs.lib.intersectLists [ "users" "video" ] (builtins.attrNames inputs.config.users.groups);
        password = "test";
        shell = inputs.pkgs.zsh;
      };
      home-manager.users.test.imports = user.sharedModules;
    };
}
