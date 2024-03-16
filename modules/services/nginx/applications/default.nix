inputs:
{
  imports = inputs.localLib.mkModules (inputs.localLib.findModules ./.);
}
