inputs:
{
  config =
  {
    services.envfs.enable = true;
    environment.variables.ENVFS_RESOLVE_ALWAYS = "1";
  };
}
