{ config, lib, ... }:
{
  services.qdrant = {
    enable = true;
    settings = {
      service = {
        host = "127.0.0.1";
        http_port = 6333;
        grpc_port = 6334;
        enable_snapshot_url_recovery = false;
      };
      storage.hnsw_index.on_disk = true;
      telemetry_disabled = true;
    };
  };

  systemd.services.qdrant = {
    restartTriggers = [ config.nixos.system.sops.templates."qdrant.env".content ];
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "qdrant";
      Group = "qdrant";
      WorkingDirectory = "/var/lib/qdrant";
      EnvironmentFile = config.nixos.system.sops.templates."qdrant.env".path;
    };
  };

  users = {
    users.qdrant = {
      isSystemUser = true;
      group = "qdrant";
    };
    groups.qdrant = { };
  };

  nixos = {
    services.nginx.https."qdrant.chn.moe" = {
      global.extraConfig = "client_max_body_size 64m;";
      location."/".proxy.upstream = "http://127.0.0.1:6333";
    };
    system.sops = {
      secrets."qdrant/api_key" = { };
      templates."qdrant.env".content = "QDRANT__SERVICE__API_KEY=${
        config.nixos.system.sops.placeholder."qdrant/api_key"
      }";
    };
  };

  environment.persistence."/nix/ssd".directories = [
    {
      directory = "/var/lib/qdrant";
      user = "qdrant";
      group = "qdrant";
      mode = "0750";
    }
  ];
}
