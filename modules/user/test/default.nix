inputs:
{
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.config.nixos) user;
    in mkIf (builtins.elem "test" user.users)
    {
      users.users.test.password = "test";
    };
}
