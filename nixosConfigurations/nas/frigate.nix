{ config, pkgs, ... }:
{
  services.frigate = {
    enable = true;
    hostname = "frigate.chn.moe";
    vaapiDriver = "iHD";
    checkConfig = false;
    settings = {
      mqtt.enabled = false;
      ffmpeg = {
        path = pkgs.ffmpeg-full;
        hwaccel_args = "preset-vaapi";
      };
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
      detectors = {
        ov = {
          type = "openvino";
          device = "GPU";
        };
      };
      model = {
        model_type = "yolo-generic";
        width = 320;
        height = 320;
        input_tensor = "nchw";
        input_dtype = "float";
        path = "${pkgs.requireFile {
          name = "yolov9-t-320.onnx";
          sha256 = "1ak6nz5w9kbxksyiz2hkrrkzh9vgjpjakj925akwxqscz19g3m2n";
          message = "Model missing from nix store. Add it using: nix-prefetch-url file:///tmp/opencode/yolov9-t-320.onnx";
        }}";
        labelmap_path = "${pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/blakeblackshear/frigate/master/labelmap.txt";
          sha256 = "02dc5zjfvcwmp8zj13spyzvkgn1li8b1qjllkx4lqd1m9wgvx138";
        }}";
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
