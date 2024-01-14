inputs:
{
  options.nixos.hardware.legion = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
  };
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.config.nixos.hardware) legion;
    in mkIf legion.enable
    {
      environment.systemPackages = [ inputs.pkgs.lenovo-legion ];
      boot.extraModulePackages = [ inputs.config.boot.kernelPackages.lenovo-legion-module ];
    };
}
