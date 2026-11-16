{
  config,
  pkgs,
  lib,
  ...
}:
let
  port = {
    api = 8888;
    controlPlane = 9999;
  };
  users = [
    "infra"
    "chn"
    "wyh"
    "lcl"
    "mhy"
    "rdhx"
  ];
  allowedBanks =
    user:
    {
      wyh = [
        "wyh"
        "lcl"
      ];
      lcl = [
        "wyh"
        "lcl"
      ];
      infra = "*";
    }
    .${user} or [ user ];
  envFile = config.nixos.system.sops.templates."hindsight.env";
  keysFile = config.nixos.system.sops.templates."hindsight-keys.json";
  llmEnvironment = {
    HINDSIGHT_API_LLM_PROVIDER = "openai";
    HINDSIGHT_API_LLM_BASE_URL = "https://internal.cliproxyapi.chn.moe/v1";
    HINDSIGHT_API_LLM_MODEL = "gemini-3.8-flash";
    HINDSIGHT_API_LLM_TIMEOUT = "600";
    HINDSIGHT_API_MENTAL_MODEL_MIN_REFRESH_INTERVAL_SECONDS = "86400";

    HINDSIGHT_API_EMBEDDINGS_PROVIDER = "openai";
    HINDSIGHT_API_EMBEDDINGS_OPENAI_BASE_URL = "https://api.siliconflow.cn/v1";
    HINDSIGHT_API_EMBEDDINGS_OPENAI_MODEL = "BAAI/bge-m3";

    HINDSIGHT_API_RERANKER_PROVIDER = "siliconflow";
    HINDSIGHT_API_RERANKER_SILICONFLOW_MODEL = "BAAI/bge-reranker-v2-m3";
  };
in
{
  config = {
    nixos = {
      services = {
        postgresql.instances.hindsight.extensions = [
          "vector"
          "pg_trgm"
          "btree_gin"
        ];
        nginx.https."hindsight.chn.moe".location = {
          "/".proxy.upstream = "http://127.0.0.1:${toString port.controlPlane}";
          "~ ^/(docs|version|openapi\\.json|health|metrics|v1|mcp)".proxy.upstream =
            "http://127.0.0.1:${toString port.api}";
        };
      };
      system.sops = {
        secrets = lib.mkMerge [
          (lib.genAttrs' users (user: lib.nameValuePair "hindsight/keys/${user}" { }))
          {
            "hindsight/siliconflow" = { };
            "hindsight/management" = { };
          }
        ];
        templates = {
          "hindsight.env".content =
            let
              inherit (config.nixos.system.sops) placeholder;
            in
            ''
              HINDSIGHT_API_DATABASE_URL=postgresql://hindsight:${
                placeholder."postgresql/hindsight"
              }@127.0.0.1:5432/hindsight
              HINDSIGHT_API_LLM_API_KEY=${placeholder."cliproxyapi/keys/infra"}
              HINDSIGHT_API_EMBEDDINGS_OPENAI_API_KEY=${placeholder."hindsight/siliconflow"}
              HINDSIGHT_API_RERANKER_SILICONFLOW_API_KEY=${placeholder."hindsight/siliconflow"}
              HINDSIGHT_CP_ACCESS_KEY=${placeholder."hindsight/management"}
              HINDSIGHT_CP_DATAPLANE_API_KEY=${placeholder."hindsight/keys/infra"}
            '';
          "hindsight-keys.json".content =
            users
            |> map (
              user:
              lib.nameValuePair config.nixos.system.sops.placeholder."hindsight/keys/${user}" (allowedBanks user)
            )
            |> lib.listToAttrs
            |> lib.toJSON;
        };
      };
    };
    systemd.services.hindsight-api = {
      description = "Hindsight API";
      after = [
        "network.target"
        "postgresql.service"
      ];
      requires = [ "postgresql.service" ];
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [
        envFile.content
        keysFile.content
      ];
      environment = llmEnvironment // {
        HOME = "/var/lib/hindsight";
        HINDSIGHT_API_HOST = "127.0.0.1";
        HINDSIGHT_API_PORT = toString port.api;
        HINDSIGHT_API_TENANT_EXTENSION = "hindsight_bank_auth:BankKeyTenantExtension";
        HINDSIGHT_API_OPERATION_VALIDATOR_EXTENSION = "hindsight_bank_auth:BankScopeValidator";
      };
      serviceConfig = {
        ExecStart = lib.getExe pkgs.localPkgs.hindsight.api;
        EnvironmentFile = envFile.path;
        LoadCredential = "keys.json:${keysFile.path}";
        DynamicUser = true;
        StateDirectory = "hindsight";
        WorkingDirectory = "/var/lib/hindsight";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
    systemd.services.hindsight-control-plane = {
      description = "Hindsight Control Plane";
      after = [
        "network.target"
        "hindsight-api.service"
      ];
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [ envFile.content ];
      environment = {
        HOSTNAME = "127.0.0.1";
        PORT = toString port.controlPlane;
        HINDSIGHT_CP_DATAPLANE_API_URL = "http://127.0.0.1:${toString port.api}";
      };
      serviceConfig = {
        ExecStart = lib.getExe pkgs.localPkgs.hindsight.control-plane;
        EnvironmentFile = envFile.path;
        DynamicUser = true;
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
