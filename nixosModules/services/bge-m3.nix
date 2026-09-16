inputs:
let
  inherit (inputs.lib)
    mkOption
    types
    mkIf
    mkMerge
    escapeShellArgs
    getExe
    ;
  inherit (inputs.config.nixos.services) bge-m3;
  port = 18080;
  package = inputs.pkgs.localPkgs.bge-m3-server;
  model = inputs.self.src.models.bge-m3;
in
{
  options.nixos.services.bge-m3 = mkOption {
    type = types.nullOr (
      types.submodule {
        options = {
          hostname = mkOption {
            type = types.str;
            default = "bgem3.chn.moe";
            description = "The domain name to expose BGE-M3 server via Nginx HTTPS.";
          };
          gpu = mkOption {
            type = types.bool;
            default = false;
            description = "Whether to use GPU (ROCm) acceleration.";
          };
        };
      }
    );
    default = null;
    description = "BGE-M3 embedding server service.";
  };

  config = mkIf (bge-m3 != null) {
    systemd.services.bge-m3 = mkMerge [
      {
        description = "BGE-M3 embedding server";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        environment = {
          HF_HUB_OFFLINE = "1";
          TRANSFORMERS_OFFLINE = "1";
          TOKENIZERS_PARALLELISM = "false";
        };
        serviceConfig = {
          Type = "simple";
          User = "bge-m3";
          Group = "bge-m3";
          ExecStart = escapeShellArgs [
            (getExe package)
            "--model"
            (toString model)
            "--host"
            "127.0.0.1"
            "--port"
            (toString port)
            "--device"
            (if bge-m3.gpu then "cuda:0" else "cpu")
            "--dtype"
            (if bge-m3.gpu then "float16" else "float32")
            "--batch-size"
            "8"
            "--max-length"
            "8192"
            "--max-inputs"
            "32"
          ];
          Restart = "on-failure";
          RestartSec = 5;
          UMask = "0077";
          CapabilityBoundingSet = [ "" ];
          LockPersonality = true;
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectClock = true;
          ProtectControlGroups = true;
          ProtectHome = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectSystem = "strict";
          RemoveIPC = true;
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_UNIX"
          ];
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          SystemCallArchitectures = "native";
        };
      }
      (mkIf bge-m3.gpu {
        environment = {
          HSA_ENABLE_SDMA = "0";
        };
        serviceConfig = {
          DevicePolicy = "closed";
          DeviceAllow = [
            "/dev/kfd rw"
            "/dev/dri/renderD128 rw"
          ];
        };
      })
    ];

    users = {
      users.bge-m3 = {
        isSystemUser = true;
        group = "bge-m3";
        extraGroups = mkIf bge-m3.gpu [
          "video"
          "render"
        ];
      };
      groups.bge-m3 = { };
    };

    nixos.services.nginx.https.${bge-m3.hostname} = {
      global.extraConfig = "client_max_body_size 16m;";
      location."/".proxy.upstream = "http://127.0.0.1:${toString port}";
    };
  };
}
