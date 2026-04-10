# sync with nixpkgs 5835771b10e3197408d3ac7d32558c8e2ae0ab8d
{ localLib, ... }:
{
  imports = localLib.findModules ./.;
}
