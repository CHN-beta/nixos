{ config, pkgs, ... }:
{
  services.frigate = {
    enable = true;
    hostname = "frigate.chn.moe";
    vaapiDriver = "radeonsi";
    checkConfig = false;
    settings = {
      mqtt.enabled = false;
      ffmpeg = {
        path = pkgs.ffmpeg-full;
        hwaccel_args = "preset-vaapi";
      };
      # Frigate config still needs go2rtc block for UI WebRTC proxying
      go2rtc = {
        streams = {
          tplink_ipc43aw = [
            "rtsp://admin:{FRIGATE_CAMERA_PASSWORD}@192.168.2.209:554/stream1#backchannel=0"
          ];
          tplink_ipc43aw_sub = [
            "rtsp://admin:{FRIGATE_CAMERA_PASSWORD}@192.168.2.209:554/stream2"
          ];
        };
      };
      cameras.tplink_ipc43aw = {
        ffmpeg.inputs = [
          {
            path = "rtsp://127.0.0.1:8554/tplink_ipc43aw";
            roles = [ "record" ];
          }
          {
            path = "rtsp://127.0.0.1:8554/tplink_ipc43aw_sub";
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
      detectors.cpu.type = "cpu";
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
      database.path = "/nix/ssd/var/lib/frigate/frigate.db";
      auth.session_length = 86400;
    };
  };
  nixos = {
    system.sops = {
      secrets = {
        "frigate/camera_password" = { };
        "frigate/jwt_secret" = { };
      };
      templates."frigate.env".content = ''
        FRIGATE_CAMERA_PASSWORD=${config.nixos.system.sops.placeholder."frigate/camera_password"}
        FRIGATE_JWT_SECRET=${config.nixos.system.sops.placeholder."frigate/jwt_secret"}
      '';
    };
    services.nginx.https."frigate.chn.moe".global.configName = "frigate.chn.moe";
  };
  services.go2rtc = {
    enable = true;
    settings = {
      streams = {
        tplink_ipc43aw = [
          # Add #backchannel=0 for ONVIF Profile T two-way audio support
          "rtsp://admin:\${FRIGATE_CAMERA_PASSWORD}@192.168.2.209:554/stream1#backchannel=0"
          # Fallback to tapo protocol if standard RTSP backchannel fails
          "tapo://admin:\${FRIGATE_CAMERA_PASSWORD}@192.168.2.209"
          "rtsp://admin:\${FRIGATE_CAMERA_PASSWORD}@192.168.2.209:554/stream1"
        ];
        tplink_ipc43aw_sub = [
          "rtsp://admin:\${FRIGATE_CAMERA_PASSWORD}@192.168.2.209:554/stream2"
        ];
      };
    };
  };
  systemd = {
    tmpfiles.rules = [
      "d /nix/ssd/var/cache/frigate 0750 frigate frigate -"
      "d /nix/ssd/var/lib/frigate 0750 frigate frigate -"
    ];
    services.go2rtc.serviceConfig = {
      EnvironmentFile = [
        config.nixos.system.sops.templates."frigate.env".path
      ];
    };
    services.frigate.serviceConfig = {
      EnvironmentFile = [
        config.nixos.system.sops.templates."frigate.env".path
      ];
      BindPaths = [
        "/nix/ssd/var/cache/frigate:/var/cache/frigate"
      ];
    };
  };
}
