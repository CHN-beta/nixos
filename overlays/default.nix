{ localLib, flakeInputs }: final: prev:
{
  localPkgs = (import ./packages { inherit localLib flakeInputs; pkgs = final; });
  pythonPackagesExtensions = prev.pythonPackagesExtensions or [] ++
    [(finalPython: prevPython: final.localPkgs.pythonOverlay finalPython)];
}
