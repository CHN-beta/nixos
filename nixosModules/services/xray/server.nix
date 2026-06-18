{
  lib,
  config,
  pkgs,
  ...
}:
let
  servers = [
    "vps4"
    "vps6"
    "vps10"
  ];
  userList = builtins.map (user: builtins.elemAt user 2) (
    builtins.filter (
      user: builtins.length user == 3 && lib.lists.hasPrefix [ "xray-server" "clients" ] user
    ) config.nixos.system.sops.availableKeys
  );
in
{
  config = lib.mkIf (lib.elem config.nixos.model.hostname servers) {
    services.xray = {
      enable = true;
      settingsFile = config.sops.templates."xray-server.json".path;
    };
    nixos = {
      system.sops = {
        templates."xray-server.json" = {
          owner = config.users.users.v2ray.name;
          group = config.users.users.v2ray.group;
          content = builtins.toJSON {
            log.loglevel = "warning";
            inbounds = [
              (
                let
                  fallbackPort = builtins.toString (
                    with config.nixos.services.nginx.global; httpsPort + httpsPortShift.http2
                  );
                in
                {
                  port = 4726;
                  listen = "127.0.0.1";
                  protocol = "vless";
                  settings = {
                    clients = builtins.map (n: {
                      id = config.nixos.system.sops.placeholder."xray-server/clients/${n}";
                      flow = "xtls-rprx-vision";
                      email = "${n}@xray.chn.moe";
                    }) userList;
                    decryption = "none";
                    fallbacks = [ { dest = "127.0.0.1:${fallbackPort}"; } ];
                  };
                  streamSettings = {
                    network = "raw";
                    security = "reality";
                    realitySettings = {
                      dest = "127.0.0.1:${fallbackPort}";
                      serverNames = [ "xserver2.chn.moe" ];
                      privateKey = config.nixos.system.sops.placeholder."xray-server/private-key";
                      minClientVer = "1.8.0";
                      shortIds = [ "" ];
                    };
                  };
                  sniffing = {
                    enabled = true;
                    destOverride = [
                      "http"
                      "tls"
                      "quic"
                    ];
                    routeOnly = true;
                  };
                  tag = "in-legacy";
                }
              )
              (
                let
                  fallbackPort = builtins.toString (
                    with config.nixos.services.nginx.global; httpsPort + httpsPortShift.http2
                  );
                in
                {
                  port = 4727;
                  listen = "127.0.0.1";
                  protocol = "vless";
                  settings = {
                    clients = builtins.map (n: {
                      id = config.nixos.system.sops.placeholder."xray-server/clients/${n}";
                      # flow = "xtls-rprx-vision";
                      email = "${n}@xray.chn.moe";
                    }) userList;
                    decryption = "none";
                    fallbacks = [ { dest = "127.0.0.1:${fallbackPort}"; } ];
                  };
                  streamSettings = {
                    network = "xhttp";
                    security = "reality";
                    realitySettings = {
                      dest = "127.0.0.1:${fallbackPort}";
                      serverNames = [ "xserver3.chn.moe" ];
                      privateKey = config.nixos.system.sops.placeholder."xray-server/private-key";
                      minClientVer = "1.8.0";
                      shortIds = [ "" ];
                    };
                    xhttpSettings.path = "/kT9hRk6D4gJ5WxNT";
                  };
                  sniffing = {
                    enabled = true;
                    destOverride = [
                      "http"
                      "tls"
                      "quic"
                    ];
                    routeOnly = true;
                  };
                  tag = "in";
                }
              )
              {
                port = 4638;
                listen = "127.0.0.1";
                protocol = "vless";
                settings = {
                  clients = [ { id = "be01f0a0-9976-42f5-b9ab-866eba6ed393"; } ];
                  decryption = "none";
                };
                streamSettings.network = "raw";
                sniffing = {
                  enabled = true;
                  destOverride = [
                    "http"
                    "tls"
                    "quic"
                  ];
                };
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
            outbounds = [
              {
                protocol = "freedom";
                tag = "freedom";
              }
              {
                protocol = "vless";
                settings.vnext = [
                  {
                    address = "127.0.0.1";
                    port = 4638;
                    users = [
                      {
                        id = "be01f0a0-9976-42f5-b9ab-866eba6ed393";
                        encryption = "none";
                      }
                    ];
                  }
                ];
                streamSettings.network = "raw";
                tag = "loopback-localdns";
              }
            ];
            routing = {
              domainStrategy = "AsIs";
              rules = builtins.map (rule: rule // { type = "field"; }) [
                {
                  inboundTag = [
                    "in-legacy"
                    "in"
                  ];
                  domain = [ "domain:openai.com" ];
                  outboundTag = "loopback-localdns";
                }
                {
                  inboundTag = [
                    "in-legacy"
                    "in"
                  ];
                  outboundTag = "freedom";
                }
                {
                  inboundTag = [ "in-localdns" ];
                  outboundTag = "freedom";
                }
                {
                  inboundTag = [ "api" ];
                  outboundTag = "api";
                }
              ];
            };
            stats = { };
            api = {
              tag = "api";
              services = [ "StatsService" ];
            };
            policy = {
              levels."0" = {
                statsUserUplink = true;
                statsUserDownlink = true;
              };
              system = {
                statsInboundUplink = true;
                statsInboundDownlink = true;
                statsOutboundUplink = true;
                statsOutboundDownlink = true;
              };
            };
          };
        };
        secrets = lib.mergeAttrsList [
          (lib.genAttrs' userList (n: lib.nameValuePair "xray-server/clients/${n}" { }))
          { "xray-server/private-key" = { }; }
          (lib.genAttrs' [ "token" "user/chn" ] (
            n:
            lib.nameValuePair "telegram/${n}" {
              group = "telegram";
              mode = "0440";
            }
          ))
        ];
      };
      services = {
        acme.cert = {
          "xserver2.chn.moe".group = config.users.users.nginx.group;
          "xserver3.chn.moe".group = config.users.users.nginx.group;
        };
        nginx = {
          transparentProxy.map = {
            "xserver2.chn.moe" = 4726;
            "xserver3.chn.moe" = 4727;
          };
          https = {
            "xserver2.chn.moe" = {
              listen.main = {
                proxyProtocol = false;
                addToTransparentProxy = false;
              };
              location."/".return.return = "400";
            };
            "xserver3.chn.moe" = {
              listen.main = {
                proxyProtocol = false;
                addToTransparentProxy = false;
              };
              location."/".return.return = "400";
            };
          };
        };
      };
    };
    systemd = {
      services = {
        xray = {
          serviceConfig = {
            DynamicUser = lib.mkForce false;
            User = "v2ray";
            Group = "v2ray";
            CapabilityBoundingSet = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
            AmbientCapabilities = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
            LimitNPROC = 65536;
            LimitNOFILE = 524288;
          };
          restartTriggers = [ config.nixos.system.sops.templates."xray-server.json".file ];
        };
        xray-stat = {
          script =
            let
              xray = "${pkgs.xray}/bin/xray";
              awk = "${pkgs.gawk}/bin/awk";
              curl = "${pkgs.curl}/bin/curl";
              jq = "${pkgs.jq}/bin/jq";
              sed = "${pkgs.gnused}/bin/sed";
              cat = "${pkgs.coreutils}/bin/cat";
              token = config.nixos.system.sops.secrets."telegram/token".path;
              chat = config.nixos.system.sops.secrets."telegram/user/chn".path;
            in
            ''
              message='${config.nixos.model.hostname} xray:\n'
              for i in ${builtins.concatStringsSep " " userList}
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
          serviceConfig = {
            Type = "oneshot";
            User = "v2ray";
            Group = "v2ray";
          };
        };
      };
      timers.xray-stat = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-* 0:00:00";
          Unit = "xray-stat.service";
        };
      };
    };
    users = {
      users.v2ray = {
        uid = config.nixos.user.uid.v2ray;
        group = "v2ray";
        extraGroups = [ "telegram" ];
        isSystemUser = true;
      };
      groups = {
        v2ray.gid = config.nixos.user.gid.v2ray;
        telegram.gid = config.nixos.user.gid.telegram;
      };
    };
  };
}
