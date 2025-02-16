inputs:
{
  options.nixos.services.ollama = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.services) ollama; in inputs.lib.mkIf (ollama != null)
  {
    services =
    {
      ollama = { enable = true; package = inputs.pkgs.pkgs-unstable.ollama; };
      open-webui = { enable = true; environment.WEBUI_AUTH = "False"; package = inputs.pkgs.pkgs-unstable.open-webui; };
    };
    nixos.packages.packages._packages = [ inputs.pkgs.oterm ];
  };
}
