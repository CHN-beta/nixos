inputs:
{
  options.nixos.services.ollama = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.services) ollama; in inputs.lib.mkIf (ollama != null)
  {
    services =
    {
      ollama.enable = true;
      open-webui =
        { enable = true; package = inputs.pkgs.genericPackages.open-webui; environment.WEBUI_AUTH = "False"; };
      nextjs-ollama-llm-ui.enable = true;
    };
    nixos.packages.packages._packages = [ inputs.pkgs.oterm ];
  };
}
