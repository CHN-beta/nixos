inputs:
{
  options.nixos.services.open-webui = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule { options =
    {
      ollamaHost = mkOption { type = types.str; };
      hostname = mkOption { type = types.str; default = "chat.chn.moe"; };
    };});
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) open-webui; in inputs.lib.mkIf (open-webui != null)
  {
    services.open-webui =
    {
      enable = true;
      package = inputs.pkgs.pkgs-unstable.open-webui;
      environment =
      {
        ENABLE_PERSISTENT_CONFIG = "False";
        ENABLE_SIGNUP = "False";
        WEBUI_URL = "https://${open-webui.hostname}";
        ADMIN_EMAIL = "chn@chn.moe";
        OLLAMA_API_BASE_URL = "http://${open-webui.ollamaHost}:11434";
        OPENAI_API_BASE_URL = "https://oa.api2d.net";
        # TASK_MODEL
        # TASK_MODEL_EXTERNAL
      };
      environmentFile = inputs.config.sops.templates."open-webui.env".path;
    };
    sops =
    {
      templates."open-webui.env".content = let inherit (inputs.config.sops) placeholder; in
      ''
        OPENAI_API_KEY=${placeholder."open-webui/openai"}
        WEBUI_SECRET_KEY=${placeholder."open-webui/webui"}
      '';
      secrets = { "open-webui/openai" = {}; "open-webui/webui" = {}; };
    };
    nixos.services.nginx =
    {
      enable = true;
      https."${open-webui.hostname}".location."/".proxy = { upstream = "http://127.0.0.1:8080"; websocket = true; };
    };
  };
}
