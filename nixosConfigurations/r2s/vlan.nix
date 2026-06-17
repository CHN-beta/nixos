{
  config = {
    systemd = {
      # otherwise coredns may start before interface up
      services.coredns = {
        after = [ "sys-subsystem-net-devices-enu1.20.device" ];
        bindsTo = [ "sys-subsystem-net-devices-enu1.20.device" ];
      };
      network = {
        netdevs = {
          "10-vlan10" = {
            netdevConfig = {
              Name = "enu1.10";
              Kind = "vlan";
            };
            vlanConfig.Id = 10;
          };
          "10-vlan20" = {
            netdevConfig = {
              Name = "enu1.20";
              Kind = "vlan";
            };
            vlanConfig.Id = 20;
          };
        };
        networks."10-enu1" = {
          matchConfig.Name = "enu1";
          vlan = [
            "enu1.10"
            "enu1.20"
          ];
        };
      };
    };
    nixos = {
      system.network.settings = {
        static = {
          "enu1.10" = {
            ip = "192.168.2.1";
            mask = 24;
          };
          "enu1.20" = {
            ip = "192.168.3.1";
            mask = 24;
          };
        };
        trust = [
          "enu1.10"
          "enu1.20"
        ];
        masquerade = [
          "enu1.10"
          "enu1.20"
        ];
      };
      services.xray.client.v2ray-forwarder.asRouter = [ "enu1.20" ];
    };
    services.dnsmasq = {
      enable = true;
      resolveLocalQueries = false;
      settings = {
        # disable dns
        port = 0;
        interface = [
          "enu1.10"
          "enu1.20"
        ];
        bind-dynamic = true;
        dhcp-range = [
          "interface:enu1.10,192.168.2.100,192.168.2.250,255.255.255.0,12h"
          "interface:enu1.20,192.168.3.100,192.168.3.250,255.255.255.0,12h"
        ];
        dhcp-option = [
          "interface:enu1.10,option:dns-server,223.5.5.5"
          "interface:enu1.20,option:dns-server,192.168.3.1"
        ];
      };
    };
    networking.firewall.allowedUDPPorts = [ 67 ];
  };
}
