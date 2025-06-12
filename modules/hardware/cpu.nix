inputs:
{
  options.nixos.hardware.cpu = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.enum [ "intel" "amd" ]); default = null; };
  config = let inherit (inputs.config.nixos.hardware) cpu; in inputs.lib.mkIf (cpu != null) (inputs.lib.mkMerge
  [
    (inputs.lib.mkIf (cpu == "intel")
    {
      hardware.cpu.intel.updateMicrocode = true;
      boot.initrd.availableKernelModules =
        [ "intel_cstate" "aesni_intel" "intel_cstate" "intel_uncore" "intel_uncore_frequency" "intel_powerclamp" ];
    })
    (inputs.lib.mkIf (cpu == "amd")
      { hardware.cpu.amd.updateMicrocode = true; environment.systemPackages = [ inputs.pkgs.zenmonitor ]; })
  ]);
}
