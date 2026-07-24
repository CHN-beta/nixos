{
  self,
  pkgs,
  lib,
  ...
}:
{
  config = {
    systemd.services =
      let
        llama-server = lib.getExe' pkgs.llama-cpp-vulkan "llama-server";
      in
      {
        llama-embedder = {
          description = "Llama.cpp Embedding Service (BGE-M3)";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          serviceConfig = {
            DynamicUser = true;
            Restart = "on-failure";
            RestartSec = "5s";
            ExecStart = ''
              ${llama-server} --host 0.0.0.0 --port 7996 -m ${self.src.models.embed} --ctx-size 8192 --embedding
            '';
          };
        };
        llama-reranker = {
          description = "Llama.cpp Reranker Service (BGE-Reranker-v2-M3)";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          serviceConfig = {
            DynamicUser = true;
            Restart = "on-failure";
            RestartSec = "5s";
            ExecStart = ''
              ${llama-server} --host 0.0.0.0 --port 7997 -m ${self.src.models.rerank} --ctx-size 8192 --reranking
            '';
          };
        };
      };
    networking.firewall.allowedTCPPorts = [
      7996
      7997
    ];
  };
}
