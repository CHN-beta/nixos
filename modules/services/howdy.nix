inputs:
{
  options.nixos.services.howdy = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.services) howdy; in inputs.lib.mkIf (howdy != null)
  {
    services =
    {
      howdy = { enable = true; settings.core.detection_notice = true; };
      linux-enable-ir-emitter.enable = true;
    };
  };
}
