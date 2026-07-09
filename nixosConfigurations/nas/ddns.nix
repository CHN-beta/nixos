{ config, ... }:
{
  config.services.ddclient = {
    enable = true;
    domains = [ "nas.chn.moe" ];
    protocol = "cloudflare";
    zone = "chn.moe";
    username = "token";
    passwordFile = config.nixos.system.sops.secrets."acme/token".path;
    usev4 = "ifv4, if=ppp0";
    usev6 = "ifv6, if=ppp0";
    interval = "5min";
    quiet = true;
  };
}
