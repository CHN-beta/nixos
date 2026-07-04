{ pkgs, ... }:
{
  services.home-assistant = {
    enable = true;
    extraComponents = [
      "default_config"
      "met"
      "radio_browser"
    ];
    customComponents = with pkgs.home-assistant-custom-components; [
      tuya_local
      xiaomi_miot
    ];
    config = {
      homeassistant = {
        name = "Home";
        time_zone = "Asia/Shanghai";
        temperature_unit = "C";
        unit_system = "metric";
      };
      default_config = { };
      http = {
        use_x_forwarded_for = true;
        trusted_proxies = [
          "127.0.0.1"
          "::1"
        ];
      };
    };
  };
  nixos.services.nginx.https."ha.chn.moe".location."/".proxy.upstream = "http://127.0.0.1:8123";
}
