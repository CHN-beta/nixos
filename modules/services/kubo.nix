inputs:
{
  options.nixos.services.kubo = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
  };
  config = let inherit (inputs.config.nixos.services) kubo; in inputs.lib.mkIf kubo.enable
  {
    services.kubo.enable = true;
  };
}
