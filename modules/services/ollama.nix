inputs:
{
  options.nixos.services.ollama = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.services) ollama; in inputs.lib.mkIf (ollama != null)
  {
    services.ollama =
    {
      enable = true;
      host = "0.0.0.0";
      environmentVariables = { OLLAMA_REGISTRY_MAXSTREAMS = "2"; OLLAMA_EXPERIMENT= "client2"; };
    };
    nixos.packages.packages._packages = [ inputs.pkgs.oterm ];
  };
}
