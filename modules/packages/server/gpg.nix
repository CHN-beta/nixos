inputs:
{
  config =
    let
      inherit (inputs.lib) mkIf;
    in mkIf (builtins.elem "server" inputs.config.nixos.packages._packageSets)
    {
      programs.gnupg.agent = { enable = true; pinentryFlavor = "tty"; };
    };
}
