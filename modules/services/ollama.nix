{ lib, config, pkgs, ... }:
{
  options.nixos.services.ollama = lib.mkOption { type = lib.types.nullOr (lib.types.submodule {}); default = null; };
  config = let inherit (config.nixos.services) ollama; in lib.mkIf (ollama != null)
  {
    services.ollama =
    {
      enable = true;
      host = "0.0.0.0";
      environmentVariables = { OLLAMA_REGISTRY_MAXSTREAMS = "2"; OLLAMA_EXPERIMENT= "client2"; };
      package = pkgs.ollama-vulkan;
    };
    nixos.packages.packages._packages = [ pkgs.oterm ];
  };
}
