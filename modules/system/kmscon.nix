inputs:
{
  config =
  {
    services.kmscon =
    {
      enable = true;
      fonts = [{ name = "FiraCode Nerd Font Mono"; package = inputs.pkgs.nerdfonts; }];
    };
  };
}
