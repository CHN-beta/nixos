inputs:
{
  options.nixos.system.envfs = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = true; };
  };
  config = inputs.lib.mkMerge
  [
    (builtins.elemAt inputs.topInputs.envfs.nixosModules.envfs.imports 0 inputs)
    { environment.variables.ENVFS_RESOLVE_ALWAYS = "1"; }
  ];
}
