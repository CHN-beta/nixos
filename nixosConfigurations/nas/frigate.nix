{ config, ... }:
{
  services.frigate = {
    enable = true;
    hostname = "frigate.chn.moe";
    vaapiDriver = "iHD";
    settings = {
      mqtt.enabled = false;
      cameras.tplink_ipc43aw = {
        ffmpeg.inputs = [
          {
            path = "rtsp://admin:{FRIGATE_CAMERA_PASSWORD}@192.168.2.209:554/stream1";
            roles = [ "record" ];
          }
          {
            path = "rtsp://admin:{FRIGATE_CAMERA_PASSWORD}@192.168.2.209:554/stream2";
            roles = [ "detect" ];
          }
        ];
        onvif = {
          host = "192.168.2.209";
          port = 80;
          user = "admin";
          password = "{FRIGATE_CAMERA_PASSWORD}";
        };
        detect = {
          enabled = true;
          width = 640;
          height = 480;
          fps = 5;
        };
        record = {
          enabled = true;
          retain = {
            days = 7;
            mode = "motion";
          };
          events = {
            retain = {
              default = 14;
              mode = "motion";
            };
          };
        };
      };
    };
  };
  nixos = {
    system.sops = {
      secrets."frigate/camera_password" = { };
      templates."frigate.env".content = ''
        FRIGATE_CAMERA_PASSWORD=${config.nixos.system.sops.placeholder."frigate/camera_password"}
      '';
    };
    services.nginx.https."frigate.chn.moe".global.configName = "frigate.chn.moe";
  };
  systemd.services.frigate.serviceConfig.EnvironmentFile = [
    config.nixos.system.sops.templates."frigate.env".path
  ];
}
