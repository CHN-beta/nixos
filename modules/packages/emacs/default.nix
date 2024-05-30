inputs:
{
  config = inputs.lib.mkIf (builtins.elem "workstation" inputs.config.nixos.packages._packageSets)
  {
    home-manager.users.chn.config.programs.doom-emacs = { enable = true; doomPrivateDir = ./doom.d; };
  };
}
