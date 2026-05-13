self: final: prev:
{
  localPkgs = (import ./packages { localLib = self.lib; flakeInputs = self.inputs; pkgs = final; });
  pythonPackagesExtensions = prev.pythonPackagesExtensions or [] ++
    [(finalPython: prevPython: final.localPkgs.pythonOverlay finalPython)];
}
