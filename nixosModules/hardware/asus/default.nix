{ lib, config, ... }:
{
  imports = [ ./rear-glow.nix ];
  options.nixos.hardware.asus = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.submodule {
        options.rearGlow = {
          enable = lib.mkEnableOption ''
            the rear window of ROG Flow Z13 (0b05:18c6): host driven
            flowing rainbow over its 11 HID LampArray lamps
          '';
          speed = lib.mkOption {
            type = lib.types.number;
            default = 30.0;
            description = "Hue degrees per second; one full cycle takes 360/speed seconds.";
          };
          fps = lib.mkOption {
            type = lib.types.number;
            default = 30.0;
            description = "LampArray update rate. The device allows up to 500 Hz (2 ms).";
          };
          direction = lib.mkOption {
            type = lib.types.enum [
              "forward"
              "reverse"
            ];
            default = "forward";
            description = "Direction the hue gradient travels along the strip.";
          };
          intensity = lib.mkOption {
            type = lib.types.ints.between 0 255;
            default = 255;
            description = "Lamp intensity, 255 is full brightness.";
          };
          span = lib.mkOption {
            type = lib.types.number;
            default = 360.0;
            description = "Total hue range spread over the lamps; 360 is a full rainbow.";
          };
          vendorRefresh = lib.mkOption {
            type = lib.types.number;
            default = 0.0;
            description = ''
              Re-send the vendor power message every N seconds, 0 sends it
              once at start (default). The rear zone has to be powered on the
              vendor Aura interface, but every such message makes the EC
              re-initialise the zone, which shows up as a one frame blink.
              Only set this if something else clears the power state, for
              example asusd after a platform profile change.
            '';
          };
        };
      }
    );
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
          fanCurvesConfig.source = ./fan_curves.ron;
        };
        supergfxd.enable = false;
      };
      programs.rog-control-center.enable = true;
      nixos.system.kernel.patches = [ "asus" ];
    };
}
