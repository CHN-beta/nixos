inputs:
{
  options.nixos.system.envfs = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = true; };
  };
  config = inputs.lib.mkMerge
  [
    (inputs.topInputs.envfs.nixosModules.envfs inputs)
    { environment.variables.ENVFS_RESOLVE_ALWAYS = "1"; }
  ];
}
