{
  # enp3s0 靠近 hdmi 口 enp2s0 远离 hdmi 口
  config = {
    systemd = {
      # otherwise coredns may start before interface up
      services.coredns = {
        after = [ "sys-subsystem-net-devices-enp2s0.20.device" ];
        bindsTo = [ "sys-subsystem-net-devices-enp2s0.20.device" ];
      };
      network = {
        netdevs = {
          "10-vlan10" = {
            netdevConfig = {
              Name = "enp2s0.10";
              Kind = "vlan";
            };
            vlanConfig.Id = 10;
          };
          "10-vlan20" = {
            netdevConfig = {
              Name = "enp2s0.20";
              Kind = "vlan";
            };
            vlanConfig.Id = 20;
          };
        };
        networks."10-enp2s0" = {
          matchConfig.Name = "enp2s0";
          vlan = [
            "enp2s0.10"
            "enp2s0.20"
          ];
        };
      };
    };
    nixos = {
      system.network.settings = {
        static = {
          "enp2s0.10" = {
            ip = "192.168.2.1";
            mask = 24;
          };
          "enp2s0.20" = {
            ip = "192.168.3.1";
            mask = 24;
          };
        };
        trust = [
          "enp2s0.10"
          "enp2s0.20"
        ];
        masquerade = [
          "enp2s0.10"
          "enp2s0.20"
        ];
      };
      services.xray.client.v2ray-forwarder.asRouter = [ "enp2s0.20" ];
    };
    services.dnsmasq = {
      enable = true;
      resolveLocalQueries = false;
      settings = {
        # disable dns
        port = 0;
        interface = [
          "enp2s0.10"
          "enp2s0.20"
        ];
        bind-dynamic = true;
        dhcp-range = [
          "interface:enp2s0.10,192.168.2.100,192.168.2.250,255.255.255.0,12h"
          "interface:enp2s0.20,192.168.3.100,192.168.3.250,255.255.255.0,12h"
        ];
        dhcp-option = [
          "interface:enp2s0.10,option:dns-server,223.5.5.5"
          "interface:enp2s0.20,option:dns-server,192.168.3.1"
        ];
      };
    };
    networking.firewall.allowedUDPPorts = [ 67 ];
  };
}
