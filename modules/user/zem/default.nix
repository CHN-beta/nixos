inputs:
{
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.config.nixos) user;
    in mkIf (builtins.elem "zem" user.users)
    {
      users.users.zem =
      {
        hashedPasswordFile = inputs.config.sops.secrets."users/zem".path;
      };
      sops.secrets."users/zem".neededForUsers = true;
    };
}
