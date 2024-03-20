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
        hashedPasswordFile = inputs.config.sops.secrets."users/xll".path;
      };
      sops.secrets."users/xll".neededForUsers = true;
    };
}
