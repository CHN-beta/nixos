inputs:
{
  options.nixos.system.envfs = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.system) envfs; in inputs.lib.mkIf (envfs != null) (inputs.lib.mkMerge
  [
    (builtins.elemAt inputs.topInputs.envfs.nixosModules.envfs.imports 0 inputs)
    { environment.variables.ENVFS_RESOLVE_ALWAYS = "1"; }
  ]);
}
