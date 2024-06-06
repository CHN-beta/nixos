inputs:
{
  config = inputs.lib.mkIf (builtins.elem "desktop-extra" inputs.config.nixos.packages._packageSets)
  {
    programs.chromium = { enable = true; extraOpts.PasswordManagerEnabled = false; };
  };
}
