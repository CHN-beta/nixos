{ localLib, config, ... }:
{
  imports = localLib.findModules ./.;
}
