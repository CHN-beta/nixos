self: final: prev:
{
  localPkgs = (import ./packages { inherit self; pkgs = final; });
  pythonPackagesExtensions = prev.pythonPackagesExtensions or [] ++
    [(finalPython: prevPython: final.localPkgs.pythonOverlay finalPython)];
}
