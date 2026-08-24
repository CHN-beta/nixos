{ self, config, ... }:
{
  imports = [ self.inputs.cliproxyapi.nixosModules.cliproxyapi ];
  config = {
    services.cliproxyapi = {
      enable = true;
      # package = self.inputs.llm-agents.packages.x86_64-linux.cli-proxy-api;
      managementPasswordFile = config.nixos.system.sops.secrets."cliproxyapi/management".path;
    };
    nixos.system.sops.secrets."cliproxyapi/management".owner = "cliproxyapi";
  };
}
