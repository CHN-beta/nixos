inputs:
{
  options.nixos.packages.vasp = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = if inputs.config.nixos.system.gui.enable then {} else null;
  };
  # TODO: add more options to correctly configure VASP
  config = let inherit (inputs.config.nixos.packages) vasp; in inputs.lib.mkIf (vasp != null)
  {
    nixos.packages.packages._packages =
      (with inputs.pkgs.localPackages.vasp;
      [
        (intel.override
        {
          integratedWithSlurm = inputs.config.nixos.services.slurm.enable;
          slurm = inputs.config.services.slurm.package;
        })
        vtstscripts
      ])
        ++ (with inputs.pkgs.localPackages; [ py4vasp vaspkit ])
        ++ (inputs.lib.optional
          (let inherit (inputs.config.nixos.system.nixpkgs) cuda; in cuda.enable && cuda.capabilities != null)
          inputs.pkgs.localPackages.vasp.nvidia);
  };
}
