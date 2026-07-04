{ pkgs, ... }:
{
  config = {
    systemd.network = {
      netdevs."10-ipv6net" = {
        netdevConfig = {
          Name = "ipv6net";
          Kind = "sit";
        };
        tunnelConfig = {
          Local = pkgs.localPkgs.getAddress "vps6";
          Remote = "45.32.66.87";
          TTL = 255;
        };
      };
      networks = {
        "10-ipv6net" = {
          matchConfig.Name = "ipv6net";
          address = [ "2607:8700:5500:2255::2/64" ];
          routes = [
            {
              Gateway = "2607:8700:5500:2255::1";
              Destination = "::/0";
            }
          ];
          linkConfig.RequiredForOnline = "routable";
        };
        "10-ens18".networkConfig.Tunnel = "ipv6net";
      };
    };
  };
}
