{ config, ... }: {
  config = {
    services.open-webui = {
      enable = true;
      environment = {
        ENABLE_PERSISTENT_CONFIG = "False";
        ENABLE_SIGNUP = "True";
        WEBUI_URL = "https://chat.chn.moe";
        ADMIN_EMAIL = "chn@chn.moe";
        OPENAI_API_BASE_URLS = "https://cliproxyapi.chn.moe/v1;http://127.0.0.1:9090/v1";
        CORS_ALLOW_ORIGIN = "https://chat.chn.moe";
        TASK_MODEL = "gemini-3.8-flash-high";
        TASK_MODEL_EXTERNAL = "gemini-3.8-flash-high";
        # ENABLE_IMAGE_GENERATION = "True";
        # IMAGES_OPENAI_API_BASE_URL = "https://oa.api2d.net/v1";
      };
      environmentFile = config.nixos.system.sops.templates."open-webui.env".path;
    };
    nixos = {
      system.sops = {
        templates."open-webui.env".content =
          let
            inherit (config.nixos.system.sops) placeholder;
          in
          # IMAGES_OPENAI_API_KEY=${placeholder."open-webui/openai"}
          ''
            OPENAI_API_KEYS=${placeholder."open-webui/openai"};${placeholder."hermes/api_server_token"}
            WEBUI_SECRET_KEY=${placeholder."open-webui/webui"}
          '';
        secrets = {
          "open-webui/openai".key = "opencode/cliproxyapi";
          "open-webui/webui" = { };
          "hermes/api_server_token" = { };
        };
      };
      services.nginx.https."chat.chn.moe".location."/".proxy.upstream = "http://127.0.0.1:8080";
    };
  };
}
