inputs:
{
  options.nixos.hardware.cpus = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.listOf (types.enum [ "intel" "amd" ]); default = []; };
  config = let inherit (inputs.config.nixos.hardware) cpus; in inputs.lib.mkIf (cpus != []) (inputs.lib.mkMerge
  [
    (inputs.lib.mkIf (builtins.elem "intel" cpus)
    {
      hardware.cpu.intel.updateMicrocode = true;
      boot.initrd.availableKernelModules =
        [ "intel_cstate" "aesni_intel" "intel_cstate" "intel_uncore" "intel_uncore_frequency" "intel_powerclamp" ];
    })
    (inputs.lib.mkIf (builtins.elem "amd" cpus)
      { hardware.cpu.amd.updateMicrocode = true; environment.systemPackages = [ inputs.pkgs.zenmonitor ]; })
  ]);
}
