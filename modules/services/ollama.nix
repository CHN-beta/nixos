inputs:
{
  options.nixos.services.ollama = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.services) ollama; in inputs.lib.mkIf (ollama != null)
  {
    services =
    {
      ollama.enable = true;
      open-webui = { enable = true; environment.WEBUI_AUTH = "False"; };
    };
    nixos.packages.packages._packages = [ inputs.pkgs.oterm ];
  };
}
