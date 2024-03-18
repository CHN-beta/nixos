inputs:
{
  options.nixos.services.xray = let inherit (inputs.lib) mkOption types; in
  {
    client = mkOption
    {
      type = types.nullOr (types.submodule { options =
      {
        xray =
        {
          serverAddress = mkOption { type = types.nonEmptyStr; default = "74.211.99.69"; };
          serverName = mkOption { type = types.nonEmptyStr; default = "vps6.xserver.chn.moe"; };
          noproxyUsers = mkOption { type = types.listOf types.nonEmptyStr; default = [ "gb" "xll" ]; };
        };
        dae =
        {
          lanInterfaces = mkOption
          {
            type = types.listOf types.nonEmptyStr;
            default = inputs.lib.optionals inputs.config.nixos.virtualization.docker.enable [ "docker0" ];
          };
          wanInterface = mkOption { type = types.listOf types.nonEmptyStr; default = [ "auto" ]; };
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
      };});
      default = null;
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
        assertion = !(xray.client != null && xray.server != null);
        message = "Currenty xray.client and xray.server could not be simutaniusly enabled.";
      }];
    }
    (
      inputs.lib.mkIf (xray.client != null)
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
              server = [ "1.1.1.1" ]; # use a random DNS, and dns query will be actually handled by dae
              interface = xray.client.dnsmasq.extraInterfaces ++ [ "lo" ];
              bind-dynamic = true;
              address = map (host: "/${host.name}/${host.value}")
                (inputs.localLib.attrsToList xray.client.dnsmasq.hosts);
            };
          };
          dae =
          {
            enable = true;
            package = inputs.pkgs.callPackage "${inputs.topInputs.nixpkgs-unstable}/pkgs/tools/networking/dae" {};
            config =
            let
              lanString = (inputs.lib.optionalString (xray.client.dae.lanInterfaces != []) "lan_interface: ")
                + builtins.concatStringsSep "," xray.client.dae.lanInterfaces;
              wanString = (inputs.lib.optionalString (xray.client.dae.wanInterface != []) "wan_interface: ")
                + builtins.concatStringsSep "," xray.client.dae.wanInterface;
            in
            ''
              global {
                tproxy_port: 12345
                tproxy_port_protect: true
                so_mark_from_dae: 0
                log_level: info
                disable_waiting_network: false
                ${lanString}
                ${wanString}
                auto_config_kernel_parameter: true

                dial_mode: ip
                allow_insecure: false
                tls_implementation: tls
              }

              node {
                'socks5://localhost:10884'
              }

              dns {
                ipversion_prefer: 4
                upstream {
                  alidns: 'udp://223.5.5.5:53'
                  googledns: 'tcp+udp://8.8.8.8:53'
                }
                routing {
                  request {
                    qname(geosite:geolocation-cn) -> alidns
                    qname(geosite:geolocation-!cn) -> googledns
                    fallback: alidns
                  }
                  response {
                    upstream(alidns) && !ip(geoip:cn) -> googledns
                    fallback: accept
                  }
                }
              }

              group {
                default_group {
                  policy: fixed(0)
                }
              }

              routing {
                dscp(0x1) -> direct

                dip(224.0.0.0/3, 'ff00::/8') -> direct
                dip(geoip:private) -> direct
                domain(geosite:geolocation-cn) -> direct
                domain(geosite:geolocation-!cn) -> default_group
                dip(8.8.8.8) -> default_group
                dip(223.5.5.5) -> direct
                dip(geoip:cn) -> direct
                !dip(geoip:cn) -> default_group
                fallback: default_group
              }
            '';
          };
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
                inbounds =
                [
                  {
                    port = 10881;
                    protocol = "dokodemo-door";
                    settings = { network = "tcp,udp"; followRedirect = true; };
                    streamSettings.sockopt.tproxy = "tproxy";
                    tag = "xmu-in";
                  }
                  { port = 10884; protocol = "socks"; settings.udp = true; tag = "proxy-in"; }
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
                    { inboundTag = [ "xmu-in" ]; outboundTag = "xmu-out"; }
                    { inboundTag = [ "direct-in" ]; outboundTag = "direct"; }
                    { inboundTag = [ "proxy-in" ]; outboundTag = "proxy-vless"; }
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
                xmuPort = "10881";
              in
              {
                Type = "simple";
                RemainAfterExit = true;
                ExecStart = inputs.pkgs.writeShellScript "v2ray-forwarder.start" (builtins.concatStringsSep "\n"
                (
                  [
                    "${ipset} create xmu_net hash:net"
                    "${iptables} -t mangle -N v2ray -w"
                    "${iptables} -t mangle -A PREROUTING -j v2ray -w"
                  ]
                  ++ (map (action: "${iptables} -t mangle -A v2ray ${action} -w")
                  [
                    "-m set --match-set xmu_net dst -p tcp -j TPROXY --on-port ${xmuPort} --tproxy-mark 1/1"
                    "-m set --match-set xmu_net dst -p udp -j TPROXY --on-port ${xmuPort} --tproxy-mark 1/1"
                  ])
                  ++ [
                    "${iptables} -t mangle -N v2ray_mark -w"
                    "${iptables} -t mangle -A OUTPUT -j v2ray_mark -w"
                  ]
                  ++ (map (action: "${iptables} -t mangle -A v2ray_mark ${action} -w")
                  (
                    [ "-m set --match-set xmu_net dst -j MARK --set-mark 1/1" ]
                    ++ (map
                      (user:
                        let uid = inputs.config.nixos.system.user.user.${user};
                        in "-m owner --uid-owner ${toString uid} -j DSCP --set-dscp 0x1")
                      (xray.client.xray.noproxyUsers ++ [ "v2ray" ]))  
                  ))
                  ++ [
                    "${ip} rule add fwmark 1/1 table 100"
                    "${ip} route add local 0.0.0.0/0 dev lo table 100"
                  ]
                ));
                ExecStop = inputs.pkgs.writeShellScript "v2ray-forwarder.stop"
                ''
                  ${iptables} -t mangle -F v2ray -w
                  ${iptables} -t mangle -D PREROUTING -j v2ray -w
                  ${iptables} -t mangle -X v2ray -w
                  ${iptables} -t mangle -F v2ray_mark -w
                  ${iptables} -t mangle -D OUTPUT -j v2ray_mark -w
                  ${iptables} -t mangle -X v2ray_mark -w
                  ${ip} rule del fwmark 1/1 table 100
                  ${ip} route del local 0.0.0.0/0 dev lo table 100
                  ${ipset} destroy xmu_net
                '';
              };
          };
        };
        users =
        {
          users.v2ray = { uid = inputs.config.nixos.system.user.user.v2ray; group = "v2ray"; isSystemUser = true; };
          groups.v2ray.gid = inputs.config.nixos.system.user.group.v2ray;
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
              (name:
              {
                name = "xray-server/telegram/${name}";
                value = (let user = inputs.config.users.users.v2ray; in { owner = user.name; inherit (user) group; });
              })
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
                  token = inputs.config.sops.secrets."xray-server/telegram/token".path;
                  chat = inputs.config.sops.secrets."xray-server/telegram/chat".path;
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
          users.v2ray = { uid = inputs.config.nixos.system.user.user.v2ray; group = "v2ray"; isSystemUser = true; };
          groups.v2ray.gid = inputs.config.nixos.system.user.group.v2ray;
        };
        nixos.services =
        {
          acme = { enable = true; cert.${xray.server.serverName}.group = inputs.config.users.users.nginx.group; };
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
