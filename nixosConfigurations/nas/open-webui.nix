{ config, ... }: {
  config = {
    services.open-webui = {
      enable = true;
      environment = {
        ENABLE_PERSISTENT_CONFIG = "False";
        ENABLE_SIGNUP = "False";
        AUTH_MAX_LOGIN_ATTEMPTS = "5";
        AUTH_LOGIN_ATTEMPT_LOCKOUT_DURATION = "900";
        ENABLE_COMMUNITY_SHARING = "False";
        USER_PERMISSIONS_CHAT_ALLOW_OPEN_SHARING = "True";
        USER_PERMISSIONS_CHAT_ALLOW_PUBLIC_SHARING = "True";
        WEBUI_URL = "https://chat.chn.moe";
        ADMIN_EMAIL = "chn@chn.moe";
        OPENAI_API_BASE_URLS = "https://cliproxyapi.chn.moe/v1";
        OLLAMA_BASE_URL = "https://ollama.chn.moe";
        DEFAULT_MODELS = "cliproxyapi/gemini-3.8-flash";
        CORS_ALLOW_ORIGIN = "https://chat.chn.moe";
        TASK_MODEL = "gemini-3.8-flash";
        TASK_MODEL_EXTERNAL = "gemini-3.8-flash";
      };
      environmentFile = config.nixos.system.sops.templates."open-webui.env".path;
    };
    nixos = {
      system.sops = {
        templates."open-webui.env".content = ''
          WEBUI_SECRET_KEY=${config.nixos.system.sops.placeholder."open-webui/webui"}
        '';
        secrets."open-webui/webui" = { };
      };
      services.nginx.https."chat.chn.moe" = {
        global.extraConfig = ''
          # Forward streaming responses immediately without buffering or caching.
          proxy_buffering off;
          proxy_cache off;
        '';
        location."/".proxy.upstream = "http://127.0.0.1:8080";
      };
    };
  };
}
