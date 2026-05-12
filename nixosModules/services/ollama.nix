{ lib, config, pkgs, ... }:
{
  options.nixos.services.ollama = lib.mkOption { type = lib.types.nullOr (lib.types.submodule {}); default = null; };
  config = let inherit (config.nixos.services) ollama; in lib.mkIf (ollama != null)
  {
    services.ollama =
    {
      enable = true;
      host = "0.0.0.0";
      environmentVariables =
      {
        # fix model pull failed
        OLLAMA_REGISTRY_MAXSTREAMS = "2";
        OLLAMA_EXPERIMENT = "client2";
        # minimize context memory usage
        OLLAMA_KV_CACHE_TYPE = "q4_0";
        OLLAMA_FLASH_ATTENTION = "1";
        OLLAMA_CONTEXT_LENGTH = "32768";
        # disable GTT usage
        HSA_ENABLE_SDMA = "0";
        # limit ollama CPU threads
        OLLAMA_NUM_THREADS = "1";
      };
      package = pkgs.pkgsUnstable.ollama;
    };
    environment.systemPackages = [ pkgs.oterm ];
  };
}
