inputs:
{
  options.nixos.hardware.asus = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.hardware) asus; in inputs.lib.mkIf (asus != null)
  {
    services =
    {
      asusd = { enable = true; enableUserService = true; asusdConfig.source = ./asusd.ron; };
      supergfxd.enable = false;
    };
    programs.rog-control-center = { enable = true; autoStart = true; };
  };
}
