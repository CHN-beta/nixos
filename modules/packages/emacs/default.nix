inputs:
{
  config = inputs.lib.mkIf (builtins.elem "workstation" inputs.config.nixos.packages._packageSets)
  {
    nixos.user.sharedModules = [{ config.programs.doom-emacs = { enable = true; doomPrivateDir = ./doom.d; }; }];
  };
}
