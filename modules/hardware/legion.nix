inputs:
{
  options.nixos.hardware.legion = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.hardware) legion; in inputs.lib.mkIf (legion != null)
  {
    environment.systemPackages = [ inputs.pkgs.lenovo-legion ];
    boot.extraModulePackages = [ inputs.config.boot.kernelPackages.lenovo-legion-module ];
  };
}
