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
        hashedPasswordFile = inputs.config.sops.secrets."users/gb".path;
      };
      sops.secrets."users/gb".neededForUsers = true;
    };
}
