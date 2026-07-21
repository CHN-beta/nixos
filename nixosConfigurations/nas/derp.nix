{ lib, ... }:
{
  config = {
    services.tailscale.derper = {
      enable = true;
      domain = "derp.chn.moe";
    };
    services.nginx.virtualHosts."derp.chn.moe" = {
      addSSL = lib.mkForce false;
      listen = [
        {
          addr = "0.0.0.0";
          port = 3443;
          ssl = true;
        }
        {
          addr = "[::]";
          port = 3443;
          ssl = true;
        }
      ];
    };
    nixos.services.nginx.https."derp.chn.moe".global.configName = "derp.chn.moe";
    networking.firewall.allowedTCPPorts = [ 3443 ];
  };
}
