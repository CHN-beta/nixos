inputs:
{
  config =
  {
    programs.yazi.enable = true;
    nixos.user.sharedModules = [{ config.programs.yazi.enable = true; }];
  };
}
