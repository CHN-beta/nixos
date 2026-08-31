{
  config = {
    services.ollama = {
      enable = true;
      host = "[::]";
      environmentVariables = {
        # minimize context memory usage
        OLLAMA_KV_CACHE_TYPE = "q4_0";
        OLLAMA_FLASH_ATTENTION = "1";
        OLLAMA_CONTEXT_LENGTH = "262144";
        # disable GTT usage
        HSA_ENABLE_SDMA = "0";
        # limit ollama CPU threads
        OLLAMA_NUM_THREADS = "1";
      };
    };
    nixos.services.nginx.https."ollama.chn.moe".location."/".proxy.upstream = "http://127.0.0.1:11434";
  };
}
