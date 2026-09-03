{
  lib,
  pkgs,
  self,
  ...
}:
let
  port = 18080;
  package = pkgs.localPkgs.bge-m3-server;
  model = self.src.models.bge-m3;
in
{
  assertions = [
    {
      assertion = pkgs.config.rocmSupport;
      message = "The NAS BGE-M3 service requires nixpkgs ROCm support";
    }
  ];

  systemd.services.bge-m3 = {
    description = "BGE-M3 ROCm embedding server";
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
      SupplementaryGroups = [
        "render"
        "video"
      ];
      ExecStart = lib.escapeShellArgs [
        (lib.getExe package)
        "--model"
        (toString model)
        "--host"
        "127.0.0.1"
        "--port"
        (toString port)
        "--device"
        "cuda:0"
        "--dtype"
        "float16"
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
  };

  users = {
    users.bge-m3 = {
      isSystemUser = true;
      group = "bge-m3";
      extraGroups = [
        "render"
        "video"
      ];
    };
    groups.bge-m3 = { };
  };

  nixos.services.nginx.https."bgem3.chn.moe" = {
    global.extraConfig = "client_max_body_size 16m;";
    location."/".proxy.upstream = "http://127.0.0.1:${toString port}";
  };
}
