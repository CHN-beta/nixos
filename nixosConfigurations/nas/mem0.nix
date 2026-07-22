{ self, config, ... }:
{
  virtualisation.oci-containers.containers = {
    "mem0-api" = {
      image = "my-mem0-api:latest";
      imageFile = self.src.mem0.api;
      volumes = [ "mem0_history:/app/history" ];
      ports = [ "127.0.0.1:8100:8000" ];
      environment = {
        PYTHONDONTWRITEBYTECODE = "1";
        PYTHONUNBUFFERED = "1";
        POSTGRES_HOST = "host.containers.internal";
        POSTGRES_PORT = "5432";
        POSTGRES_DB = "mem0";
        POSTGRES_USER = "mem0";
        DASHBOARD_URL = "https://mem0.chn.moe";
        APP_DB_NAME = "mem0";
        AUTH_DISABLED = "false";
        OPENAI_API_BASE = "https://api.siliconflow.cn/v1";
      };
      cmd = [
        "sh"
        "-c"
        "alembic upgrade head && uvicorn main:app --host 0.0.0.0 --port 8000"
      ];
      environmentFiles = [ config.nixos.system.sops.templates."mem0-api.env".path ];
    };
    "mem0-dashboard" = {
      image = "my-mem0-dashboard:latest";
      imageFile = self.src.mem0.dashboard;
      ports = [ "127.0.0.1:3100:3000" ];
      environment = {
        NEXT_PUBLIC_API_URL = "https://mem0-api.chn.moe";
        API_INTERNAL_URL = "https://mem0-api.chn.moe";
        NEXT_PUBLIC_INSTANCE_NAME = "Mem0";
      };
    };
  };
  nixos = {
    services = {
      postgresql.instances.mem0.extensions = [ "vector" ];
      nginx.https = {
        "mem0.chn.moe".location."/".proxy.upstream = "http://127.0.0.1:3100";
        "mem0-api.chn.moe".location."/".proxy.upstream = "http://127.0.0.1:8100";
      };
    };
    system.sops = {
      secrets = {
        "mem0/siliconflow_key" = { };
        "mem0/jwtSecret" = { };
      };
      templates."mem0-api.env".content = ''
        POSTGRES_PASSWORD=${config.nixos.system.sops.placeholder."postgresql/mem0"}
        JWT_SECRET=${config.nixos.system.sops.placeholder."mem0/jwtSecret"}
        OPENAI_API_KEY=${config.nixos.system.sops.placeholder."mem0/siliconflow_key"}
      '';
    };
  };
}
