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
        hashedPasswordFile = inputs.config.sops.secrets."users/yjq".path;
      };
      sops.secrets."users/yjq".neededForUsers = true;
    };
}
