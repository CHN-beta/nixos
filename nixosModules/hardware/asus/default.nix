{ lib, config, ... }:
{
  options.nixos.hardware.asus = lib.mkOption {
    type = lib.types.nullOr (lib.types.submodule { });
    default = null;
  };
  config =
    let
      inherit (config.nixos.hardware) asus;
    in
    lib.mkIf (asus != null) {
      services = {
        asusd = {
          enable = true;
          asusdConfig.source = ./asusd.ron;
        };
        supergfxd.enable = false;
      };
      programs.rog-control-center.enable = true;
      nixos.system.kernel.patches = [ "asus" ];
    };
}
