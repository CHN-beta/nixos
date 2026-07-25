{
  config,
  self,
  ...
}:
{
  config = {
    nixos = {
      services = {
        postgresql.instances.hindsight.extensions = [ "vector" ];
        nginx.https."hindsight.chn.moe".location = {
          "/".proxy.upstream = "http://127.0.0.1:9999";
          "~ ^/(docs|openapi\\.json|health|metrics|v1|mcp)".proxy.upstream = "http://127.0.0.1:8888";
        };
      };
      system.sops = {
        templates."hindsight.env".content =
          let
            inherit (config.nixos.system.sops) placeholder;
          in
          ''
            HINDSIGHT_API_DATABASE_URL=postgresql://hindsight:${
              placeholder."postgresql/hindsight"
            }@host.containers.internal:5432/hindsight
            HINDSIGHT_API_LLM_API_KEY=${placeholder."hindsight/siliconflow"}
            HINDSIGHT_API_EMBEDDINGS_OPENAI_API_KEY=${placeholder."hindsight/siliconflow"}
            HINDSIGHT_API_RERANKER_SILICONFLOW_API_KEY=${placeholder."hindsight/siliconflow"}
            HINDSIGHT_API_TENANT_API_KEY=${placeholder."hindsight/password"}
            HINDSIGHT_CP_ACCESS_KEY=${placeholder."hindsight/password"}
            HINDSIGHT_CP_DATAPLANE_API_KEY=${placeholder."hindsight/password"}
          '';
        secrets = {
          "hindsight/siliconflow" = { };
          "hindsight/password" = { };
        };
      };
    };
    systemd.services.podman-hindsight = {
      after = [ "postgresql.service" ];
      restartTriggers = [ config.nixos.system.sops.templates."hindsight.env".content ];
    };
    virtualisation.oci-containers.containers.hindsight = {
      image = "hindsight:latest";
      imageFile = self.src.hindsight;
      ports = [
        "127.0.0.1:8888:8888"
        "127.0.0.1:9999:9999"
      ];
      environmentFiles = [ config.nixos.system.sops.templates."hindsight.env".path ];
      environment = {
        HINDSIGHT_API_LLM_PROVIDER = "openai";
        HINDSIGHT_API_LLM_BASE_URL = "https://api.siliconflow.cn/v1";
        HINDSIGHT_API_LLM_MODEL = "deepseek-ai/DeepSeek-V4-Flash";

        HINDSIGHT_API_EMBEDDINGS_PROVIDER = "openai";
        HINDSIGHT_API_EMBEDDINGS_OPENAI_BASE_URL = "https://api.siliconflow.cn/v1";
        HINDSIGHT_API_EMBEDDINGS_OPENAI_MODEL = "BAAI/bge-m3";

        HINDSIGHT_API_RERANKER_PROVIDER = "siliconflow";
        HINDSIGHT_API_RERANKER_SILICONFLOW_MODEL = "BAAI/bge-reranker-v2-m3";
      };
    };
  };
}
