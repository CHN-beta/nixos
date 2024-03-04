inputs:
{
  options.nixos.system.envfs = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
  };
  config = inputs.lib.mkIf inputs.config.nixos.system.envfs.enable (inputs.lib.mkMerge
  [
    (builtins.elemAt inputs.topInputs.envfs.nixosModules.envfs.imports 0 inputs)
    { environment.variables.ENVFS_RESOLVE_ALWAYS = "1"; }
  ]);
}
