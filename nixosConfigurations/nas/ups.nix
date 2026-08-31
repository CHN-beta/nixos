{ pkgs, ... }:
let
  upsmonPasswordFile = pkgs.writeText "nut-upsmon-password" "upsmon-password-local";
in
{
  environment.systemPackages = [ pkgs.nut ];
  power.ups = {
    enable = true;
    mode = "standalone";
    ups."nas-ups" = {
      driver = "nutdrv_qx";
      port = "auto";
      directives = [
        "vendorid = 0665"
        "productid = 5161"
        "subdriver = cypress"
        "override.battery.runtime.low = 300"
        "default.ups.realpower.nominal = 360"
        "default.ups.power.nominal = 650"
      ];
    };
    users."upsmon" = {
      passwordFile = "${upsmonPasswordFile}";
      upsmon = "primary";
    };
    upsmon.monitor."nas-ups" = {
      user = "upsmon";
      passwordFile = "${upsmonPasswordFile}";
      type = "primary";
    };
  };
}
