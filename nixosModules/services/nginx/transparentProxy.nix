{ lib, config, pkgs, ... }:
{
  options.nixos.services.nginx.transparentProxy =
  {
    # proxy to 127.0.0.1:${specified port}
    map = lib.mkOption
    {
      type = lib.types.attrsOf (lib.types.oneOf
      [
        # proxy to 127.0.0.1:${specified port}
        lib.types.ints.unsigned
        # proxy to specified ip:port
        lib.types.nonEmptyStr
      ]);
      default = {};
    };
  };
  config = let inherit (config.nixos.services) nginx; in lib.mkIf (nginx.transparentProxy.map != {})
  {
    services.nginx.streamConfig =
    ''
      log_format transparent_proxy '[$time_local] $remote_addr-$geoip2_data_country_code '
        '"$ssl_preread_server_name"->$transparent_proxy_backend $bytes_sent $bytes_received';
      map $ssl_preread_server_name $transparent_proxy_backend {
        ${builtins.concatStringsSep "\n    " (lib.mapAttrsToList
          (n: v: ''"${n}" ${if builtins.isInt v then "127.0.0.1:${builtins.toString v}" else v};'')
          nginx.transparentProxy.map)}
        default 127.0.0.1:${toString (with nginx.global; (httpsPort + httpsPortShift.http2))};
      }
      server {
        listen 0.0.0.0:443;
        ssl_preread on;
        proxy_bind $remote_addr transparent;
        proxy_pass $transparent_proxy_backend;
        proxy_connect_timeout 1s;
        proxy_socket_keepalive on;
        proxy_buffer_size 128k;
        access_log syslog:server=unix:/dev/log transparent_proxy;
      }
    '';
    systemd =
    {
      services = lib.mkIf (config.nixos.system.network.implementation == "networkmanager")
      {
        nginx-proxy =
          let
            ip = "${pkgs.iproute2}/bin/ip";
            start = pkgs.writeShellScript "nginx-proxy.start"
            ''
              ${ip} rule add fwmark 2/2 table 200 priority 5001
              ${ip} route add local 0.0.0.0/0 dev lo table 200
            '';
            stop = pkgs.writeShellScript "nginx-proxy.stop"
            ''
              ${ip} rule del fwmark 2/2 table 200 priority 5001
              ${ip} route del local 0.0.0.0/0 dev lo table 200
            '';
          in
          {
            description = "nginx transparent proxy";
            after = [ "network.target" ];
            serviceConfig =
            {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = start;
              ExecStop = stop;
            };
            wants = [ "network.target" ];
            wantedBy= [ "multi-user.target" ];
          };
      };
      network.networks = lib.mkIf (config.nixos.system.network.implementation == "systemd-networkd")
      {
        "10-custom" =
        {
          matchConfig.Name = "lo";
          routes = [{ Table = 200; Destination = "0.0.0.0/0"; Type = "local"; }];
          routingPolicyRules = [{ FirewallMark = "2/2"; Table = 200; Priority = 5001; }];
        };
      };
    };
    networking.nftables.tables.nginx =
    {
      family = "inet";
      content =
      ''
        chain output {
          type route hook output priority mangle; policy accept;
          # 由本机发出、gid 为 nginx、但源地址不是本地监听的地址，说明是透明代理的第一个包，将这个流标记
          # 但这个包本身不需要处理，正常路由即可。
          meta skgid ${builtins.toString config.users.groups.nginx.gid} fib saddr type != local \
            ct state new counter ct mark set ct mark | 2 return
          # 由本机发出、作为透明代理的回复，它不能按照通常的路由，它需要被打上标记并被路由到本地
          # 这对应于透明代理到本地的服务的情况
          ct mark & 2 == 2 ct direction reply counter meta mark set meta mark | 2 return
          return
        }
        # 还需要处理透明代理到其它机器的情况，它们的回复需要在 prerouting 中标记
        chain prerouting {
          type filter hook prerouting priority mangle; policy accept;
          ct mark & 2 == 2 ct direction reply counter meta mark set meta mark | 2 return
          return
        }
      '';
    };
  };
}
