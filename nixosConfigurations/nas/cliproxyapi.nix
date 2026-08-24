{ self, config, ... }:
{
  imports = [ self.inputs.cliproxyapi.nixosModules.cliproxyapi ];
  config = {
    services.cliproxyapi = {
      enable = true;
      managementPasswordFile = config.nixos.system.sops.secrets."cliproxyapi/management".path;
    };
    nixos = {
      system.sops.secrets."cliproxyapi/management".owner = "cliproxyapi";
      services.nginx.https."cliproxyapi.chn.moe".location."/".proxy.upstream = "http://127.0.0.1:8317";
    };
  };
}
