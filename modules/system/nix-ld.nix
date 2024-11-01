inputs:
{
  config =
  {
    programs.nix-ld = { enable = true; libraries = [ inputs.pkgs.steam-run.fhsenv ]; };
  };
}
