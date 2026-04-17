{ lib, config, ... }:
{
  options.nixos.services.howdy = lib.mkOption { type = lib.types.nullOr (lib.types.submodule {}); default = null; };
  config = let inherit (config.nixos.services) howdy; in lib.mkIf (howdy != null)
  {
    services =
    {
      howdy = { enable = true; control = "sufficient"; settings.core.detection_notice = true; };
      linux-enable-ir-emitter.enable = true;
    };
  };
}
