inputs:
{
	options.nixos.services = let inherit (inputs.lib) mkOption types; in
	{
		impermanence =
		{
			enable = mkOption { type = types.bool; default = false; };
			persistence = mkOption { type = types.nonEmptyStr; default = "/nix/persistent"; };
			root = mkOption { type = types.nonEmptyStr; default = "/nix/rootfs/current"; };
		};
    snapper =
    {
      enable = mkOption { type = types.bool; default = false; };
      configs = mkOption { type = types.attrsOf types.nonEmptyStr; default = {}; };
    };
		kmscon.enable = mkOption { type = types.bool; default = false; };
		fontconfig.enable = mkOption { type = types.bool; default = false; };
		u2f.enable = mkOption { type = types.bool; default = false; };
		sops =
		{
			enable = mkOption { type = types.bool; default = false; };
			keyPathPrefix = mkOption { type = types.str; default = ""; };
		};
		samba =
		{
			enable = mkOption { type = types.bool; default = false; };
			wsdd = mkOption { type = types.bool; default = false; };
			private = mkOption { type = types.bool; default = false; };
			hostsAllowed = mkOption { type = types.str; default = "127."; };
			shares = mkOption
			{
				type = types.attrsOf (types.submodule { options =
				{
					comment = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
					path = mkOption { type = types.nonEmptyStr; };
				};});
				default = {};
			};
		};
		sshd.enable = mkOption { type = types.bool; default = false; };
		xrayClient =
		{
			enable = mkOption { type = types.bool; default = false; };
			serverAddress = mkOption { type = types.nonEmptyStr; };
			serverName = mkOption { type = types.nonEmptyStr; };
			dns = mkOption { type = types.submodule { options =
			{
				hosts = mkOption { type = types.attrsOf types.nonEmptyStr; default = {}; };
				extraInterfaces = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
			}; }; };
		};
		xrayServer =
		{
			enable = mkOption { type = types.bool; default = false; };
			serverName = mkOption { type = types.nonEmptyStr; };
		};
		firewall.trustedInterfaces = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
		acme =
		{
			enable = mkOption { type = types.bool; default = false; };
			certs = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
		};
		frpClient =
		{
			enable = mkOption { type = types.bool; default = false; };
			serverName = mkOption { type = types.nonEmptyStr; };
			user = mkOption { type = types.nonEmptyStr; };
			tcp = mkOption
			{
				type = types.attrsOf (types.submodule
				{
					options =
					{
						localIp = mkOption { type = types.nonEmptyStr; };
						localPort = mkOption { type = types.ints.unsigned; };
						remotePort = mkOption { type = types.ints.unsigned; };
					};
				});
				default = {};
			};
		};
		frpServer =
		{
			enable = mkOption { type = types.bool; default = false; };
			serverName = mkOption { type = types.nonEmptyStr; };
		};
		nix-serve.enable = mkOption { type = types.bool; default = false; };
		smartd.enable = mkOption { type = types.bool; default = false; };
		nginx =
		{
			transparentProxy =
			{
				enable = mkOption { type = types.bool; default = false; };
				externalIp = mkOption { type = types.nonEmptyStr; };
				map = mkOption { type = types.attrsOf types.ints.unsigned; };
			};
			httpProxy = mkOption
			{
				type = types.attrsOf (types.submodule { options =
				{
					upstream = mkOption { type = types.nonEmptyStr; };
					rewriteHttps = mkOption { type = types.bool; default = false; };
					# setHeaders = mkOption { type = types.attrsOf types.nonEmptyStr; default = {}; };
					# addPin = mkOption { type = types.bool; default = false; };
					# detectPin = mkOption { type = types.bool; default = false; };
				}; });
				default = {};
			};
		};
	};
	config =
		let
			inherit (inputs.lib) mkMerge mkIf;
			inherit (inputs.localLib) stripeTabs attrsToList;
			inherit (inputs.config.nixos) services;
			inherit (builtins) map listToAttrs concatStringsSep toString elemAt genList length attrNames attrValues;
		in mkMerge
		[
			(
				mkIf services.impermanence.enable
				{
					environment.persistence =
					{
						"${services.impermanence.persistence}" =
						{
							hideMounts = true;
							directories =
							[
								"/etc/NetworkManager/system-connections"
								"/home"
								"/root"
								"/var/db"
								"/var/lib"
								"/var/log"
								"/var/spool"
							];
							files =
							[
								"/etc/machine-id"
								"/etc/ssh/ssh_host_ed25519_key.pub"
								"/etc/ssh/ssh_host_ed25519_key"
								"/etc/ssh/ssh_host_rsa_key.pub"
								"/etc/ssh/ssh_host_rsa_key"
							];
						};
						"${services.impermanence.root}" =
						{
							hideMounts = true;
							directories = []
								++ (if inputs.config.services.xserver.displayManager.sddm.enable then
									[{ directory = "/var/lib/sddm"; user = "sddm"; group = "sddm"; mode = "0700"; }] else []);
						};
					};
				}
			)
			(
				mkIf services.snapper.enable
				{
					services.snapper.configs =
						let
							f = (config:
							{
								inherit (config) name;
								value =
								{
									SUBVOLUME = config.value;
									TIMELINE_CREATE = true;
									TIMELINE_CLEANUP = true;
									TIMELINE_MIN_AGE = 1800;
									TIMELINE_LIMIT_HOURLY = "10";
									TIMELINE_LIMIT_DAILY = "7";
									TIMELINE_LIMIT_WEEKLY = "1";
									TIMELINE_LIMIT_MONTHLY = "0";
									TIMELINE_LIMIT_YEARLY = "0";
								};
							});
						in
							listToAttrs (map f (attrsToList services.snapper.configs));
					nixpkgs.config.packageOverrides = pkgs: 
					{
						snapper = pkgs.snapper.overrideAttrs (attrs:
						{
							patches = (if (attrs ? patches) then attrs.patches else []) ++ [ ./snapper.patch ];
						});
					};
				}
			)
			(
				mkIf services.kmscon.enable
				{
					services.kmscon =
					{
						enable = true;
						fonts = [{ name = "FiraCode Nerd Font Mono"; package = inputs.pkgs.nerdfonts; }];
					};
				}
			)
			(
				mkIf services.fontconfig.enable
				{
					fonts =
					{
						fontDir.enable = true;
						packages = with inputs.pkgs;
							[ noto-fonts source-han-sans source-han-serif source-code-pro hack-font jetbrains-mono nerdfonts ];
						fontconfig.defaultFonts =
						{
							emoji = [ "Noto Color Emoji" ];
							monospace = [ "Noto Sans Mono CJK SC" "Sarasa Mono SC" "DejaVu Sans Mono"];
							sansSerif = [ "Noto Sans CJK SC" "Source Han Sans SC" "DejaVu Sans" ];
							serif = [ "Noto Serif CJK SC" "Source Han Serif SC" "DejaVu Serif" ];
						};
					};
				}
			)
			(
				mkIf services.sops.enable
				{
					sops =
					{
						defaultSopsFile = ../../secrets/${inputs.config.networking.hostName}.yaml;
						# sops start before impermanence, so we need to use the absolute path
						age.sshKeyPaths = [ "${services.sops.keyPathPrefix}/etc/ssh/ssh_host_ed25519_key" ];
						gnupg.sshKeyPaths = [ "${services.sops.keyPathPrefix}/etc/ssh/ssh_host_rsa_key" ];
					};
				}
			)
			(
				mkIf services.samba.enable
				{
					# make shares visible for windows 10 clients
					services =
					{
						samba-wsdd.enable = services.samba.wsdd;
						samba =
						{
							enable = true;
							openFirewall = !services.samba.private;
							securityType = "user";
							extraConfig = stripeTabs
							''
								workgroup = WORKGROUP
								server string = Samba Server
								server role = standalone server
								hosts allow = ${services.samba.hostsAllowed}
								dns proxy = no
							'';
							#	obey pam restrictions = yes
							#	encrypt passwords = no
							shares = listToAttrs (map
								(share:
								{
									name = share.name;
									value =
									{
										comment = if share.value.comment != null then share.value.comment else share.name;
										path = share.value.path;
										browseable = true;
										writeable = true;
										"create mask" = "664";
										"force create mode" = "644";
										"directory mask" = "2755";
										"force directory mode" = "2755";
									};
								})
								(attrsToList services.samba.shares));
						};
					};
				}
			)
			(
				mkIf services.sshd.enable
				{
					services.openssh =
					{
						enable = true;
						settings =
						{
							X11Forwarding = true;
							TrustedUserCAKeys = "${inputs.config.security.pam.ussh.caFile}";
							ChallengeResponseAuthentication = false;
							PasswordAuthentication = false;
							KbdInteractiveAuthentication = false;
							UsePAM = true;
						};
					};
				}
			)
			(
				mkIf services.xrayClient.enable
				{
					services =
					{
						dnsmasq =
						{
							enable = true;
							settings =
							{
								no-poll = true;
								log-queries = true;
								server = [ "127.0.0.1#10853" ];
								interface = services.xrayClient.dns.extraInterfaces ++ [ "lo" ];
								bind-dynamic = true;
								ipset =
								[
									"/developer.download.nvidia.com/noproxy_net"
									"/yuanshen.com/noproxy_net"
									"/zoom.us/noproxy_net"
								];
								address = map (host: "/${host.name}/${host.value}") (attrsToList services.xrayClient.dns.hosts);
							};
						};
						xray = { enable = true; settingsFile = inputs.config.sops.templates."xray-client.json".path; };
						v2ray-forwarder = { enable = true; proxyPort = 10880; xmuPort = 10881; };
					};
					sops =
					{
						templates."xray-client.json" =
						{
							owner = inputs.config.users.users.v2ray.name;
							group = inputs.config.users.users.v2ray.group;
							content = builtins.toJSON
							{
								log.loglevel = "info";
								dns =
								{
									servers =
									[
										{ address = "223.5.5.5"; domains = [ "geosite:geolocation-cn" ]; port = 53; skipFallback = true; }
										{ address = "8.8.8.8"; domains = [ "geosite:geolocation-!cn" ]; port = 53; skipFallback = true; }
										{ address = "223.5.5.5"; expectIPs = [ "geoip:cn" ]; }
										{ address = "8.8.8.8"; }
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
									{ port = 10882; protocol = "socks"; tag = "direct-in"; }
								];
								outbounds =
								[
									{
										protocol = "vless";
										settings.vnext =
										[{
											address = services.xrayClient.serverAddress;
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
												serverName = services.xrayClient.serverName;
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
								];
								routing =
								{
									domainStrategy = "AsIs";
									rules = builtins.map (rule: rule // { type = "field"; })
									[
										{ inboundTag = [ "dns-in" ]; outboundTag = "dns-out"; }
										{ inboundTag = [ "xmu-in" ]; outboundTag = "xmu-out"; }
										{ inboundTag = [ "direct-in" ]; outboundTag = "direct"; }
										{ inboundTag = [ "common-in" ]; domain = [ "geosite:geolocation-cn" ]; outboundTag = "direct"; }
										{
											inboundTag = [ "common-in" ];
											domain = [ "geosite:geolocation-!cn" ];
											outboundTag = "proxy-vless";
										}
										{ inboundTag = [ "common-in" "dns-internal" ]; ip = [ "geoip:cn" ]; outboundTag = "direct"; }
										{ inboundTag = [ "common-in" "dns-internal" ]; outboundTag = "proxy-vless"; }
									];
								};
							};
						};
						secrets."xray-client/uuid" = {};
					};
					systemd.services.xray =
					{
						serviceConfig =
						{
							DynamicUser = inputs.lib.mkForce false;
							User = "v2ray";
							Group = "v2ray";
							CapabilityBoundingSet = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
							AmbientCapabilities = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
							LimitNPROC = 10000;
							LimitNOFILE = 1000000;
						};
						restartTriggers = [ inputs.config.sops.templates."xray-client.json".file ];
					};
					users = { users.v2ray = { isSystemUser = true; group = "v2ray"; }; groups.v2ray = {}; };
					environment.etc."resolv.conf".text = "nameserver 127.0.0.1";
				}
			)
			(
				mkIf services.xrayServer.enable (let userList = genList (n: n) 30; in
				{
					services =
					{
						xray = { enable = true; settingsFile = inputs.config.sops.templates."xray-server.json".path; };
						nginx.virtualHosts.xray =
						{
							serverName = services.xrayServer.serverName;
							default = true;
							listen = [{ addr = "127.0.0.1"; port = 7233; ssl = true; }];
							useACMEHost = services.xrayServer.serverName;
							locations."/".return = "400";
						};
					};
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
											fallbacks = [{ dest = "127.0.0.1:7233"; }];
										};
										streamSettings =
										{
											network = "tcp";
											security = "reality";
											realitySettings =
											{
												dest = "127.0.0.1:7233";
												serverNames = [ services.xrayServer.serverName ];
												privateKey = inputs.config.sops.placeholder."xray-server/private-key";
												minClientVer = "1.8.3";
												shortIds = [ "" ];
											};
										};
										sniffing = { enabled = true; destOverride = [ "http" "tls" "quic" ]; routeOnly = true; };
										tag = "in";
									}
									{
										port = 4638;
										listen = "127.0.0.1";
										protocol = "vless";
										settings =
										{
											clients = [{ id = "be01f0a0-9976-42f5-b9ab-866eba6ed393"; }];
											decryption = "none";
										};
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
						secrets = listToAttrs (map (n: { name = "xray-server/clients/user${toString n}"; value = {}; }) userList)
							// (listToAttrs (map
								(name:
								{
									name = "xray-server/telegram/${name}";
									value =
									{
										owner = inputs.config.users.users.v2ray.name;
										group = inputs.config.users.users.v2ray.group;
									};
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
									LimitNPROC = 10000;
									LimitNOFILE = 1000000;
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
									in stripeTabs
									''
										message='xray:\n'
										for i in {0..${toString ((length userList) - 1)}}
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
					users = { users.v2ray = { isSystemUser = true; group = "v2ray"; }; groups.v2ray = {}; };
					nixos.services =
					{
						acme = { enable = true; certs = [ services.xrayServer.serverName ]; };
						nginx.transparentProxy =
						{
							enable = true;
							map."${services.xrayServer.serverName}" = 4726;
						};
					};
					security.acme.certs.${services.xrayServer.serverName}.group = inputs.config.users.users.nginx.group;
				}
			))
			{ networking.firewall.trustedInterfaces = services.firewall.trustedInterfaces; }
			(
				mkIf services.acme.enable
				{
					security.acme =
					{
						acceptTerms = true;
						defaults.email = "chn@chn.moe";
						certs = listToAttrs (map
							(name:
							{
								name = name; value =
								{
									dnsProvider = "cloudflare";
									credentialsFile = inputs.config.sops.secrets."acme/cloudflare.ini".path;
								};
							})
							services.acme.certs);
					};
					sops.secrets."acme/cloudflare.ini" = {};
				}
			)
			(
				mkIf (services.frpClient.enable)
				{
					systemd.services.frpc =
						let
							frpc = "${inputs.pkgs.frp}/bin/frpc";
							config = inputs.config.sops.templates."frpc.ini";
						in
						{
							description = "Frp Client Service";
							after = [ "network.target" ];
							serviceConfig =
							{
								Type = "simple";
								User = "frp";
								Restart = "always";
								RestartSec = "5s";
								ExecStart = "${frpc} -c ${config.path}";
								LimitNOFILE = 1048576;
							};
							wantedBy= [ "multi-user.target" ];
							restartTriggers = [ config.file ];
						};
					sops =
					{
						templates."frpc.ini" =
						{
							owner = inputs.config.users.users.frp.name;
							group = inputs.config.users.users.frp.group;
							content = inputs.lib.generators.toINI {}
							(
								{
									common =
									{
										server_addr = services.frpClient.serverName;
										server_port = 7000;
										token = inputs.config.sops.placeholder."frp/token";
										user = services.frpClient.user;
										tls_enable = true;
									};
								}
								// (listToAttrs (map
									(tcp:
									{
										name = tcp.name;
										value =
										{
											type = "tcp";
											local_ip = tcp.value.localIp;
											local_port = tcp.value.localPort;
											remote_port = tcp.value.remotePort;
											use_compression = true;
										};
									})
									(attrsToList services.frpClient.tcp))
								)
							);
						};
						secrets."frp/token" = {};
					};
					users = { users.frp = { isSystemUser = true; group = "frp"; }; groups.frp = {}; };
				}
			)
			(
				mkIf (services.frpServer.enable)
				{
					systemd.services.frps =
						let
							frps = "${inputs.pkgs.frp}/bin/frps";
							config = inputs.config.sops.templates."frps.ini";
						in
						{
							description = "Frp Server Service";
							after = [ "network.target" ];
							serviceConfig =
							{
								Type = "simple";
								User = "frp";
								Restart = "on-failure";
								RestartSec = "5s";
								ExecStart = "${frps} -c ${config.path}";
								LimitNOFILE = 1048576;
							};
							wantedBy= [ "multi-user.target" ];
							restartTriggers = [ config.file ];
						};
					sops =
					{
						templates."frps.ini" =
						{
							owner = inputs.config.users.users.frp.name;
							group = inputs.config.users.users.frp.group;
							content = inputs.lib.generators.toINI {}
							{
								common = let cert = inputs.config.security.acme.certs.${services.frpServer.serverName}.directory; in
								{
									bind_port = 7000;
									bind_udp_port = 7000;
									token = inputs.config.sops.placeholder."frp/token";
									tls_cert_file = "${cert}/full.pem";
									tls_key_file = "${cert}/key.pem";
									tls_only = true;
									user_conn_timeout = 30;
								};
							};
						};
						secrets."frp/token" = {};
					};
					nixos.services.acme = { enable = true; certs = [ services.frpServer.serverName ]; };
					security.acme.certs.${services.frpServer.serverName}.group = "frp";
					users = { users.frp = { isSystemUser = true; group = "frp"; }; groups.frp = {}; };
					networking.firewall.allowedTCPPorts = [ 7000 ];
				}
			)
			(
				mkIf services.nix-serve.enable
				{
					services.nix-serve =
					{
						enable = true;
						openFirewall = true;
						secretKeyFile = inputs.config.sops.secrets."store/signingKey".path;
					};
					sops.secrets."store/signingKey" = {};
				}
			)
			(mkIf services.smartd.enable { services.smartd.enable = true; })
			(
				mkIf services.nginx.transparentProxy.enable
				{
					services.nginx =
					{
						enable = true;
						# TODO: fix geoip country
						streamConfig = stripeTabs
						''
							log_format stream '[$time_local] $remote_addr-$geoip_country_code "$ssl_preread_server_name"->$backend $bytes_sent $bytes_received';
							access_log syslog:server=unix:/dev/log stream;
							map $ssl_preread_server_name $backend
							{
								${concatStringsSep "\n" (map
									(x: ''								"${x.name}" 127.0.0.1:${toString x.value};'')
									(attrsToList services.nginx.transparentProxy.map))}
								default 127.0.0.1:443;
							}
							server
							{
								listen ${services.nginx.transparentProxy.externalIp}:443;
								ssl_preread on;
								proxy_bind $remote_addr transparent;
								proxy_pass $backend;
								proxy_connect_timeout 1s;
								proxy_socket_keepalive on;
								proxy_buffer_size 128k;
							}
						'';
						recommendedZstdSettings = true;
						recommendedTlsSettings = true;
						recommendedProxySettings = true;
						recommendedOptimisation = true;
						recommendedGzipSettings = true;
						recommendedBrotliSettings = true;
						package = inputs.pkgs.nginxMainline;
					};
					systemd.services =
					{
						nginx-proxy =
							let
								ipset = "${inputs.pkgs.ipset}/bin/ipset";
								iptables = "${inputs.pkgs.iptables}/bin/iptables";
								ip = "${inputs.pkgs.iproute}/bin/ip";
								start = inputs.pkgs.writeShellScript "nginx-proxy.start"
								(
									(
										stripeTabs
										''
											${ipset} create nginx_proxy_port bitmap:port range 0-65535
											${iptables} -t mangle -N nginx_proxy_mark
											${iptables} -t mangle -A OUTPUT -j nginx_proxy_mark
											${iptables} -t mangle -A nginx_proxy_mark -s 127.0.0.1 -p tcp \
												-m set --match-set nginx_proxy_port src -j MARK --set-mark 2/2
											${iptables} -t mangle -N nginx_proxy
											${iptables} -t mangle -A PREROUTING -j nginx_proxy
											${iptables} -t mangle -A nginx_proxy -s 127.0.0.1 -p tcp \
												-m set --match-set nginx_proxy_port src -j MARK --set-mark 2/2
											${ip} rule add fwmark 2/2 table 200
											${ip} route add local 0.0.0.0/0 dev lo table 200
										''
									)
									+ concatStringsSep "\n" (map
											(port: ''${ipset} add nginx_proxy_port ${toString port}'')
											((attrValues services.nginx.transparentProxy.map) ++ [ 443 ]) )
								);
								stop = inputs.pkgs.writeShellScript "nginx-proxy.stop" (stripeTabs
								''
									${iptables} -t mangle -F nginx_proxy_mark
									${iptables} -t mangle -D OUTPUT -j nginx_proxy_mark
									${iptables} -t mangle -X nginx_proxy_mark
									${iptables} -t mangle -F nginx_proxy
									${iptables} -t mangle -D PREROUTING -j nginx_proxy
									${iptables} -t mangle -X nginx_proxy
									${ip} rule del fwmark 2/2 table 200
									${ip} route del local 0.0.0.0/0 dev lo table 200
									${ipset} destroy nginx_proxy_port
								'');
							in
							{
								description = "nginx transparent proxy";
								after = [ "network.target" ];
								serviceConfig =
								{
									Type = "simple";
									RemainAfterExit = true;
									ExecStart = start;
									ExecStop = stop;
								};
								wants = [ "network.target" ];
								wantedBy= [ "multi-user.target" ];
							};
						nginx.serviceConfig =
						{
							CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];
							AmbientCapabilities = [ "CAP_NET_ADMIN" ];
						};
					};
					networking.firewall.allowedTCPPorts = [ 443 ];
				}
			)
			(
				mkIf (services.nginx.httpProxy != {})
				{
					services.nginx.virtualHosts = listToAttrs (map
						(site:
						{
							inherit (site) name;
							value =
							{
								serverName = site.name;
								listen = [{ addr = "127.0.0.1"; port = 443; ssl = true; }];
								useACMEHost = site.name;
								locations."/".proxyPass = site.value.upstream;
								forceSSL = site.value.rewriteHttps;
							};
						})
						(attrsToList services.nginx.httpProxy));
					nixos.services =
					{
						nginx.transparentProxy.enable = true;
						acme =
						{
							enable = true;
							certs = attrNames services.nginx.httpProxy;
						};
					};
					security.acme.certs = listToAttrs (map
						(cert: { name = cert; value.group = inputs.config.services.nginx.group; })
						(attrNames services.nginx.httpProxy));
				}
			)
		];
}
