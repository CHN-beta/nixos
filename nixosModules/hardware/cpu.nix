{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.nixos.hardware.cpu = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.enum [
        "intel"
        "amd"
      ]
    );
    default =
      let
        inherit (config.nixos.system.nixpkgs) march;
      in
      if march == null then
        null
      else if lib.hasInfix "znver" march then
        "amd"
      else if
        (lib.hasInfix "lake" march)
        || (builtins.elem march [
          "sandybridge"
          "silvermont"
          "haswell"
          "broadwell"
        ])
      then
        "intel"
      else
        null;
  };
  config =
    let
      inherit (config.nixos.hardware) cpu;
    in
    lib.mkIf (cpu != null) (
      lib.mkMerge [
        (lib.mkIf (cpu == "intel") {
          hardware.cpu.intel.updateMicrocode = true;
          boot.initrd.availableKernelModules = [
            "intel_cstate"
            "aesni_intel"
            "intel_cstate"
            "intel_uncore"
            "intel_uncore_frequency"
            "intel_powerclamp"
          ];
        })
        (lib.mkIf (cpu == "amd") {
          hardware.cpu.amd = {
            updateMicrocode = true;
            ryzen-smu.enable = true;
          };
          environment.systemPackages = with pkgs; [
            zenmonitor
            ryzenadj
          ];
          programs.ryzen-monitor-ng.enable = true;
        })
      ]
    );
}
