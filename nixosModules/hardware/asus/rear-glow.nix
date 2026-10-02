{
  config,
  lib,
  pkgs,
  ...
}:
let
  asus = config.nixos.hardware.asus;
  cfg = if asus == null then null else asus.rearGlow;

  # the rear window hidraw nodes are root only, so this runs as a system
  # service; the script itself needs nothing but python3 and /dev/hidraw*
  rearGlow = pkgs.writers.writePython3Bin "asus-rear-glow" {
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./rear-glow.py);
in
{
  config = lib.mkIf (cfg != null && cfg.enable) {
    systemd.services.asus-rear-glow = {
      description = "ASUS ROG Flow Z13 rear window flowing rainbow (HID LampArray)";
      wantedBy = [ "multi-user.target" ];
      after = [ "asusd.service" ];
      serviceConfig = {
        ExecStart = lib.concatStringsSep " " [
          (lib.getExe rearGlow)
          "--speed"
          (builtins.toJSON cfg.speed)
          "--fps"
          (builtins.toJSON cfg.fps)
          "--intensity"
          (builtins.toJSON cfg.intensity)
          "--span"
          (builtins.toJSON cfg.span)
          "--direction"
          cfg.direction
          "--vendor-refresh"
          (builtins.toJSON cfg.vendorRefresh)
        ];
        Restart = "always";
        RestartSec = 5;
      };
    };
  };
}
