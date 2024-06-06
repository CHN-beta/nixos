inputs:
{
  options.nixos.services.xray = let inherit (inputs.lib) mkOption types; in
  {
    client =
    {
      enable = mkOption { type = types.bool; default = false; };
      xray =
      {
        serverAddress = mkOption { type = types.nonEmptyStr; default = "74.211.99.69"; };
        serverName = mkOption { type = types.nonEmptyStr; default = "vps6.xserver.chn.moe"; };
      };
      dnsmasq =
      {
        extraInterfaces = mkOption
        {
          type = types.listOf types.nonEmptyStr;
          default = inputs.lib.optional inputs.config.nixos.virtualization.docker.enable "docker0";
        };
        hosts = mkOption { type = types.attrsOf types.nonEmptyStr; default = {}; };
      };
      v2ray-forwarder =
      {
        noproxyUsers = mkOption { type = types.listOf types.nonEmptyStr; default = [ "gb" "xll" ]; };
        noproxyTcpPorts = mkOption { type = types.listOf types.ints.unsigned; default = []; };
        noproxyUdpPorts = mkOption { type = types.listOf types.ints.unsigned; default = []; };
      };
    };
    server = mkOption
    {
      type = types.nullOr (types.submodule { options =
      {
        serverName = mkOption { type = types.nonEmptyStr; };
        userNumber = mkOption { type = types.ints.unsigned; };
      };});
      default = null;
    };
  };
  config = let inherit (inputs.config.nixos.services) xray; in inputs.lib.mkMerge
  [
    {
      assertions =
      [{
        assertion = !(xray.client.enable && xray.server != null);
        message = "Currenty xray.client and xray.server could not be simutaniusly enabled.";
      }];
    }
    (
      inputs.lib.mkIf xray.client.enable
      {
        services =
        {
          xray = { enable = true; settingsFile = inputs.config.sops.templates."xray-client.json".path; };
          dnsmasq =
          {
            enable = true;
            settings =
            {
              no-poll = true;
              log-queries = true;
              server = [ "127.0.0.1#10853" ];
              interface = xray.client.dnsmasq.extraInterfaces ++ [ "lo" ];
              bind-dynamic = true;
              address = map (host: "/${host.name}/${host.value}")
                (inputs.localLib.attrsToList xray.client.dnsmasq.hosts);
            };
          };
          resolved.enable = false;
        };
        sops =
        {
          templates."xray-client.json" =
          {
            owner = inputs.config.users.users.v2ray.name;
            group = inputs.config.users.users.v2ray.group;
            content =
              let
                chinaDns = "223.5.5.5";
                foreignDns = "8.8.8.8";
              in
              builtins.toJSON
              {
                log.loglevel = "info";
                dns =
                {
                  servers =
                  # 先尝试匹配域名列表进行查询，若匹配成功则使用前两个 dns 查询。
                  # 若匹配域名列表失败，或者匹配成功但是查询到的 IP 不在期望的 IP 列表中，则回落到使用后两个 dns 依次查询。
                  [
                    {
                      address = chinaDns;
                      domains = [ "geosite:geolocation-cn" ];
                      expectIPs = [ "geoip:cn" ];
                      skipFallback = true;
                    }
                    {
                      address = foreignDns;
                      domains = [ "geosite:geolocation-!cn" ];
                      expectIPs = [ "geoip:!cn" ];
                      skipFallback = true;
                    }
                    { address = chinaDns; expectIPs = [ "geoip:cn" ]; }
                    { address = foreignDns; }
                  ];
                  disableCache = true;
                  queryStrategy = "UseIPv4";
                  tag = "dns-internal";
                };
                inbounds =
                [
                  {
                    port = 10853;
                    protocol = "dokodemo-door";
                    settings = { address = "8.8.8.8"; network = "tcp,udp"; port = 53; };
                    tag = "dns-in";
                  }
                  {
                    port = 10880;
                    protocol = "dokodemo-door";
                    settings = { network = "tcp,udp"; followRedirect = true; };
                    streamSettings.sockopt.tproxy = "tproxy";
                    sniffing = { enabled = true; destOverride = [ "http" "tls" "quic" ]; routeOnly = true; };
                    tag = "common-in";
                  }
                  {
                    port = 10881;
                    protocol = "dokodemo-door";
                    settings = { network = "tcp,udp"; followRedirect = true; };
                    streamSettings.sockopt.tproxy = "tproxy";
                    tag = "xmu-in";
                  }
                  {
                    port = 10883;
                    protocol = "dokodemo-door";
                    settings = { network = "tcp,udp"; followRedirect = true; };
                    streamSettings.sockopt.tproxy = "tproxy";
                    tag = "proxy-in";
                  }
                  { port = 10884; protocol = "socks"; settings.udp = true; tag = "proxy-socks-in"; }
                  { port = 10882; protocol = "socks"; settings.udp = true; tag = "direct-in"; }
                ];
                outbounds =
                [
                  {
                    protocol = "vless";
                    settings.vnext =
                    [{
                      address = xray.client.xray.serverAddress;
                      port = 443;
                      users =
                      [{
                        id = inputs.config.sops.placeholder."xray-client/uuid";
                        encryption = "none";
                        flow = "xtls-rprx-vision-udp443";
                      }];
                    }];
                    streamSettings =
                    {
                      network = "tcp";
                      security = "reality";
                      realitySettings =
                      {
                        serverName = xray.client.xray.serverName;
                        publicKey = "Nl0eVZoDF9d71_3dVsZGJl3UWR9LCv3B14gu7G6vhjk";
                        fingerprint = "firefox";
                      };
                    };
                    tag = "proxy-vless";
                  }
                  { protocol = "freedom"; tag = "direct"; }
                  { protocol = "dns"; tag = "dns-out"; }
                  {
                    protocol = "socks";
                    settings.servers = [{ address = "127.0.0.1"; port = 10069; }];
                    tag = "xmu-out";
                  }
                  { protocol = "blackhole"; tag = "block"; }
                ];
                routing =
                {
                  domainStrategy = "AsIs";
                  rules = builtins.map (rule: rule // { type = "field"; })
                  [
                    { inboundTag = [ "dns-in" ]; outboundTag = "dns-out"; }
                    { inboundTag = [ "dns-internal" ]; ip = [ chinaDns ]; outboundTag = "direct"; }
                    { inboundTag = [ "dns-internal" ]; ip = [ foreignDns ]; outboundTag = "proxy-vless"; }
                    { inboundTag = [ "dns-internal" ]; outboundTag = "block"; }
                    { inboundTag = [ "xmu-in" ]; outboundTag = "xmu-out"; }
                    { inboundTag = [ "direct-in" ]; outboundTag = "direct"; }
                    { inboundTag = [ "proxy-in" "proxy-socks-in" ]; outboundTag = "proxy-vless"; }
                    { inboundTag = [ "common-in" ]; domain = [ "geosite:geolocation-cn" ]; outboundTag = "direct"; }
                    {
                      inboundTag = [ "common-in" ];
                      domain = [ "geosite:geolocation-!cn" ];
                      outboundTag = "proxy-vless";
                    }
                    { inboundTag = [ "common-in" ]; ip = [ "geoip:cn" ]; outboundTag = "direct"; }
                    { inboundTag = [ "common-in" ]; outboundTag = "proxy-vless"; }
                  ];
                };
              };
          };
          secrets."xray-client/uuid" = {};
        };
        systemd.services =
        {
          xray =
          {
            serviceConfig =
            {
              DynamicUser = inputs.lib.mkForce false;
              User = "v2ray";
              Group = "v2ray";
              CapabilityBoundingSet = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
              AmbientCapabilities = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
              LimitNPROC = 65536;
              LimitNOFILE = 524288;
            };
            restartTriggers = [ inputs.config.sops.templates."xray-client.json".file ];
          };
          v2ray-forwarder =
          {
            description = "v2ray-forwarder Daemon";
            after = [ "network.target" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig =
              let
                ipset = "${inputs.pkgs.ipset}/bin/ipset";
                iptables = "${inputs.pkgs.iptables}/bin/iptables";
                ip = "${inputs.pkgs.iproute}/bin/ip";
                autoPort = "10880";
                xmuPort = "10881";
                proxyPort = "10883";
              in
              {
                Type = "simple";
                RemainAfterExit = true;
                ExecStart = inputs.pkgs.writeShellScript "v2ray-forwarder.start" (builtins.concatStringsSep "\n"
                (
                  [ "${ipset} create lo_net hash:net" ]
                  ++ (builtins.map (host: "${ipset} add lo_net ${host}")
                  [
                    "0.0.0.0/8" "10.0.0.0/8" "100.64.0.0/10" "127.0.0.0/8" "169.254.0.0/16" "172.16.0.0/12"
                    "192.0.0.0/24" "192.88.99.0/24" "192.168.0.0/16" "59.77.0.143" "198.18.0.0/15"
                    "198.51.100.0/24" "203.0.113.0/24" "224.0.0.0/4" "240.0.0.0/4" "255.255.255.255/32"
                  ])
                  ++ [
                    "${ipset} create xmu_net hash:net"
                    "${ipset} create noproxy_net hash:net"
                    "${ipset} add noproxy_net 223.5.5.5"
                    "${ipset} create noproxy_src_net hash:net"
                    "${ipset} create noproxy_port bitmap:port range 0-65535"
                    "${ipset} create proxy_net hash:net"
                    "${ipset} add proxy_net 8.8.8.8"
                    "${iptables} -t mangle -N v2ray -w"
                    "${iptables} -t mangle -A PREROUTING -j v2ray -w"
                  ]
                  ++ (map (port: "${ipset} add noproxy_port ${port}")
                    (with xray.client.v2ray-forwarder;
                      (map (port: "tcp:${toString port}") noproxyTcpPorts)
                        ++ (map (port: "udp:${toString port}") noproxyUdpPorts))
                  )
                  ++ (map (action: "${iptables} -t mangle -A v2ray ${action} -w")
                  [
                    "-m set --match-set noproxy_src_net src -j RETURN"
                    "-m set --match-set noproxy_net dst -j RETURN"
                    "-m set --match-set noproxy_port src -j RETURN"
                    "-m set --match-set xmu_net dst -p tcp -j TPROXY --on-port ${xmuPort} --tproxy-mark 1/1"
                    "-m set --match-set xmu_net dst -p udp -j TPROXY --on-port ${xmuPort} --tproxy-mark 1/1"
                    "-m set --match-set proxy_net dst -p tcp -j TPROXY --on-port ${proxyPort} --tproxy-mark 1/1"
                    "-m set --match-set proxy_net dst -p udp -j TPROXY --on-port ${proxyPort} --tproxy-mark 1/1"
                    "-m set --match-set lo_net dst -j RETURN"
                    "-p tcp -j TPROXY --on-port ${autoPort} --tproxy-mark 1/1"
                    "-p udp -j TPROXY --on-port ${autoPort} --tproxy-mark 1/1"
                  ])
                  ++ [
                    "${iptables} -t mangle -N v2ray_mark -w"
                    "${iptables} -t mangle -A OUTPUT -j v2ray_mark -w"
                  ]
                  ++ (map (action: "${iptables} -t mangle -A v2ray_mark ${action} -w")
                  (
                    (map
                      (user:
                        let uid = inputs.config.nixos.user.uid.${user};
                        in "-m owner --uid-owner ${toString uid} -j RETURN")
                      (xray.client.v2ray-forwarder.noproxyUsers ++ [ "v2ray" ]))
                    ++ [
                      "-m set --match-set noproxy_src_net src -j RETURN"
                      "-m set --match-set noproxy_net dst -j RETURN"
                      "-m set --match-set noproxy_port src -j RETURN"
                      "-m set --match-set xmu_net dst -j MARK --set-mark 1/1"
                      "-m set --match-set proxy_net dst -j MARK --set-mark 1/1"
                      "-m set --match-set lo_net dst -j RETURN"
                      "-j MARK --set-mark 1/1"
                    ]
                  ))
                  ++ [
                    "${ip} rule add fwmark 1/1 table 100"
                    "${ip} route add local 0.0.0.0/0 dev lo table 100"
                  ]
                ));
                ExecStop = inputs.pkgs.writeShellScript "v2ray-forwarder.stop" (builtins.concatStringsSep "\n"
                (
                  [
                    "${iptables} -t mangle -F v2ray -w"
                    "${iptables} -t mangle -D PREROUTING -j v2ray -w"
                    "${iptables} -t mangle -X v2ray -w"
                    "${iptables} -t mangle -F v2ray_mark -w"
                    "${iptables} -t mangle -D OUTPUT -j v2ray_mark -w"
                    "${iptables} -t mangle -X v2ray_mark -w"
                    "${ip} rule del fwmark 1/1 table 100"
                    "${ip} route del local 0.0.0.0/0 dev lo table 100"
                  ]
                  ++ (map (set: "${ipset} destroy ${set}")
                    [ "lo_net" "xmu_net" "noproxy_net" "noproxy_src_net" "proxy_net" "noproxy_port" ])
                ));
              };
          };
        };
        users =
        {
          users.v2ray = { uid = inputs.config.nixos.user.uid.v2ray; group = "v2ray"; isSystemUser = true; };
          groups.v2ray.gid = inputs.config.nixos.user.gid.v2ray;
        };
        environment.etc."resolv.conf".text = "nameserver 127.0.0.1";
      }
    )
    (
      inputs.lib.mkIf (xray.server != null) (let userList = builtins.genList (n: n) xray.server.userNumber; in
      {
        services.xray = { enable = true; settingsFile = inputs.config.sops.templates."xray-server.json".path; };
        sops =
        {
          templates."xray-server.json" =
          {
            owner = inputs.config.users.users.v2ray.name;
            group = inputs.config.users.users.v2ray.group;
            content = builtins.toJSON
            {
              log.loglevel = "warning";
              inbounds =
              [
                (
                  let
                    fallbackPort = toString
                      (with inputs.config.nixos.services.nginx.global; httpsPort + httpsPortShift.http2);
                  in
                  {
                    port = 4726;
                    listen = "127.0.0.1";
                    protocol = "vless";
                    settings =
                    {
                      clients = map
                        (n:
                        {
                          id = inputs.config.sops.placeholder."xray-server/clients/user${toString n}";
                          flow = "xtls-rprx-vision";
                          email = "${toString n}@xray.chn.moe";
                        })
                        userList;
                      decryption = "none";
                      fallbacks = [{ dest = "127.0.0.1:${fallbackPort}"; }];
                    };
                    streamSettings =
                    {
                      network = "tcp";
                      security = "reality";
                      realitySettings =
                      {
                        dest = "127.0.0.1:${fallbackPort}";
                        serverNames = [ xray.server.serverName ];
                        privateKey = inputs.config.sops.placeholder."xray-server/private-key";
                        minClientVer = "1.8.0";
                        shortIds = [ "" ];
                      };
                    };
                    sniffing = { enabled = true; destOverride = [ "http" "tls" "quic" ]; routeOnly = true; };
                    tag = "in";
                  }
                )
                {
                  port = 4638;
                  listen = "127.0.0.1";
                  protocol = "vless";
                  settings = { clients = [{ id = "be01f0a0-9976-42f5-b9ab-866eba6ed393"; }]; decryption = "none"; };
                  streamSettings.network = "tcp";
                  sniffing = { enabled = true; destOverride = [ "http" "tls" "quic" ]; };
                  tag = "in-localdns";
                }
                {
                  listen = "127.0.0.1";
                  port = 6149;
                  protocol = "dokodemo-door";
                  settings.address = "127.0.0.1";
                  tag = "api";
                }
              ];
              outbounds =
              [
                { protocol = "freedom"; tag = "freedom"; }
                {
                  protocol = "vless";
                  settings.vnext =
                  [{
                    address = "127.0.0.1";
                    port = 4638;
                    users = [{ id = "be01f0a0-9976-42f5-b9ab-866eba6ed393"; encryption = "none"; }];
                  }];
                  streamSettings.network = "tcp";
                  tag = "loopback-localdns";
                }
              ];
              routing =
              {
                domainStrategy = "AsIs";
                rules = builtins.map (rule: rule // { type = "field"; })
                [
                  { inboundTag = [ "in" ]; domain = [ "domain:openai.com" ]; outboundTag = "loopback-localdns"; }
                  { inboundTag = [ "in" ]; outboundTag = "freedom"; }
                  { inboundTag = [ "in-localdns" ]; outboundTag = "freedom"; }
                  { inboundTag = [ "api" ]; outboundTag = "api"; }
                ];
              };
              stats = {};
              api = { tag = "api"; services = [ "StatsService" ]; };
              policy =
              {
                levels."0" = { statsUserUplink = true; statsUserDownlink = true; };
                system =
                {
                  statsInboundUplink = true;
                  statsInboundDownlink = true;
                  statsOutboundUplink = true;
                  statsOutboundDownlink = true;
                };
              };
            };
          };
          secrets = builtins.listToAttrs
            (map (n: { name = "xray-server/clients/user${toString n}"; value = {}; }) userList)
            // (builtins.listToAttrs (map
              (name: { name = "telegram/${name}"; value = { group = "telegram"; mode = "0440"; }; })
              [ "token" "chat" ]))
            // { "xray-server/private-key" = {}; };
        };
        systemd =
        {
          services =
          {
            xray =
            {
              serviceConfig =
              {
                DynamicUser = inputs.lib.mkForce false;
                User = "v2ray";
                Group = "v2ray";
                CapabilityBoundingSet = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
                AmbientCapabilities = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
                LimitNPROC = 65536;
                LimitNOFILE = 524288;
              };
              restartTriggers = [ inputs.config.sops.templates."xray-server.json".file ];
            };
            xray-stat =
            {
              script =
                let
                  xray = "${inputs.pkgs.xray}/bin/xray";
                  awk = "${inputs.pkgs.gawk}/bin/awk";
                  curl = "${inputs.pkgs.curl}/bin/curl";
                  jq = "${inputs.pkgs.jq}/bin/jq";
                  sed = "${inputs.pkgs.gnused}/bin/sed";
                  cat = "${inputs.pkgs.coreutils}/bin/cat";
                  token = inputs.config.sops.secrets."telegram/token".path;
                  chat = inputs.config.sops.secrets."telegram/chat".path;
                in
                ''
                  message='xray:\n'
                  for i in {0..${toString ((builtins.length userList) - 1)}}
                  do
                    upload_bytes=$(${xray} api stats --server=127.0.0.1:6149 \
                      -name "user>>>''${i}@xray.chn.moe>>>traffic>>>uplink" | ${jq} '.stat.value' | ${sed} 's/"//g')
                    [ -z "$upload_bytes" ] && upload_bytes=0
                    download_bytes=$(${xray} api stats --server=127.0.0.1:6149 \
                      -name "user>>>''${i}@xray.chn.moe>>>traffic>>>downlink" | ${jq} '.stat.value' | ${sed} 's/"//g')
                    [ -z "$download_bytes" ] && download_bytes=0
                    traffic_gb=$(echo | ${awk} "{printf \"%.3f\",(''${upload_bytes}+''${download_bytes})/1073741824}")
                    message="$message$i"'\t'"''${traffic_gb}"'G\n'
                  done
                  ${curl} -X POST -H 'Content-Type: application/json' \
                    -d "{\"chat_id\": \"$(${cat} ${chat})\", \"text\": \"$message\"}" \
                    https://api.telegram.org/bot$(${cat} ${token})/sendMessage
                '';
              serviceConfig = { Type = "oneshot"; User = "v2ray"; Group = "v2ray"; };
            };
          };
          timers.xray-stat =
          {
            wantedBy = [ "timers.target" ];
            timerConfig = { OnCalendar = "*-*-* 0:00:00"; Unit = "xray-stat.service"; };
          };
        };
        users =
        {
          users.v2ray =
          {
            uid = inputs.config.nixos.user.uid.v2ray;
            group = "v2ray";
            extraGroups = [ "telegram" ];
            isSystemUser = true;
          };
          groups =
          {
            v2ray.gid = inputs.config.nixos.user.gid.v2ray;
            telegram.gid = inputs.config.nixos.user.gid.telegram;
          };
        };
        nixos.services =
        {
          acme.cert.${xray.server.serverName}.group = inputs.config.users.users.nginx.group;
          nginx =
          {
            enable = true;
            transparentProxy.map."${xray.server.serverName}" = 4726;
            https."${xray.server.serverName}" =
            {
              listen.main = { proxyProtocol = false; addToTransparentProxy = false; };
              location."/".return.return = "400";
            };
          };
        };
      }
    ))
  ];
}
