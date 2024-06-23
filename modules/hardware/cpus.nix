inputs:
{
  options.nixos.hardware.cpus = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.listOf (types.enum [ "intel" "amd" ]); default = []; };
  config = let inherit (inputs.config.nixos.hardware) cpus; in inputs.lib.mkIf (cpus != [])
  {
    hardware.cpu = builtins.listToAttrs
      (builtins.map (name: { inherit name; value = { updateMicrocode = true; }; }) cpus);
    boot =
    {
      initrd.availableKernelModules =
        let modules =
        {
          intel =
          [
            "intel_cstate" "aesni_intel" "intel_cstate" "intel_uncore" "intel_uncore_frequency" "intel_powerclamp"
          ];
          amd = [];
        };
        in builtins.concatLists (builtins.map (cpu: modules.${cpu}) cpus);
      kernelParams =
        let params = { intel = [ "intel_iommu=off" ]; amd = [ "amd_iommu=fullflush" ]; };
        in builtins.concatLists (builtins.map (cpu: params.${cpu}) cpus);
    };
    environment.systemPackages =
      let packages = with inputs.pkgs; { intel = []; amd = [ zenmonitor ]; };
      in builtins.concatLists (builtins.map (cpu: packages.${cpu}) cpus);
  };
}
