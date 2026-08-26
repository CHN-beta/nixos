{ self, config, ... }:
{
  imports = [ self.inputs.cliproxyapi.nixosModules.cliproxyapi ];
  config = {
    services.cliproxyapi = {
      enable = true;
      package = self.inputs.llm-agents.packages.x86_64-linux.cli-proxy-api.overrideAttrs (prev: {
        postInstall = prev.postInstall + ''
          ln -s cli-proxy-api $out/bin/cliproxyapi
        '';
      });
      managementPasswordFile = config.nixos.system.sops.secrets."cliproxyapi/management".path;
    };
    nixos = {
      system.sops.secrets."cliproxyapi/management".owner = "cliproxyapi";
      services.nginx.https."cliproxyapi.chn.moe".location."/".proxy.upstream = "http://127.0.0.1:8317";
    };
  };
}
