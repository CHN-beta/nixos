inputs:
{
  config = inputs.lib.mkIf (builtins.elem "workstation" inputs.config.nixos.packages._packageSets)
  {
    nixos.packages._packages =
    (
      (builtins.map
        (version: (inputs.pkgs.localPackages.vasp.intel.override
          { slurm = inputs.config.services.slurm.package; }).${version})
        [ "6.3.1" "6.4.0" ])
      ++ (builtins.concatLists (builtins.map
        (compiler: builtins.map (version: inputs.pkgs.localPackages.vasp.${compiler}.${version}) [ "6.3.1" "6.4.0" ])
        [ "gnu" "gnu-mkl" "nvidia" "amd" ]))
    );
  };
}
