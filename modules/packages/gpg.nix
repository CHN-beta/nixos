inputs:
{
  config = inputs.lib.mkIf (builtins.elem "server" inputs.config.nixos.packages._packageSets)
  {
    programs.gnupg.agent = { enable = true; pinentryFlavor = "tty"; };
  };
}
