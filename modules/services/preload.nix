inputs:
{
  options.nixos.services.preload = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.services) preload; in inputs.lib.mkIf (preload != null)
    { services.preload.enable = true; };
}
