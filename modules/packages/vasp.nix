inputs:
{
  config = inputs.lib.mkIf (builtins.elem "workstation" inputs.config.nixos.packages._packageSets)
  {
    nixos.packages._packages = builtins.concatLists (builtins.map
      (compiler: builtins.map (version: inputs.pkgs.localPackages.vasp.${compiler}.${version}) [ "6.3.1" "6.4.0" ])
      [ "amd" "gnu" "gnu-mkl" "intel" "nvidia" ]);
  };
}
