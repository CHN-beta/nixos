inputs:
{
	imports = inputs.localLib.mkModules
	[
		./postgresql.nix
		./redis.nix
		./rsshub.nix
		./misskey.nix
		./nginx.nix
		# ./docker.nix
	];
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
				type = types.attrsOf (types.submodule (inputs:
				{
					options =
					{
						localIp = mkOption { type = types.nonEmptyStr; default = "127.0.0.1"; };
						localPort = mkOption { type = types.ints.unsigned; };
						remoteIp = mkOption { type = types.nonEmptyStr; default = "127.0.0.1"; };
						remotePort = mkOption { type = types.ints.unsigned; default = inputs.config.localPort; };
					};
				}));
				default = {};
			};
		};
		frpServer =
		{
			enable = mkOption { type = types.bool; default = false; };
			serverName = mkOption { type = types.nonEmptyStr; };
		};
		nix-serve =
		{
			enable = mkOption { type = types.bool; default = false; };
			hostname = mkOption { type = types.nonEmptyStr; };
		};
		smartd.enable = mkOption { type = types.bool; default = false; };
		fileshelter.enable = mkOption { type = types.bool; default = false; };
		wallabag.enable = mkOption { type = types.bool; default = false; };
	};
	config =
		let
			inherit (inputs.lib) mkMerge mkIf;
			inherit (inputs.localLib) stripeTabs attrsToList;
			inherit (inputs.config.nixos) services;
			inherit (builtins) map listToAttrs concatStringsSep toString elemAt genList length attrNames attrValues
				concatLists;
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
							TrustedUserCAKeys = builtins.toString ./ca.pub;
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
										{ address = "223.5.5.5"; domains = [ "geosite:geolocation-cn" ]; port = 53; }
										{ address = "8.8.8.8"; domains = [ "geosite:geolocation-!cn" "domain:worldcat.org" ]; port = 53; }
										{ address = "223.5.5.5"; expectIPs = [ "geoip:cn" ]; }
										{ address = "8.8.8.8"; }
									];
									disableCache = true;
									queryStrategy = "UseIPv4";
									disableFallback = true;
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
									{ port = 10884; protocol = "socks"; tag = "proxy-socks-in"; }
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
										{ inboundTag = [ "proxy-in" "proxy-socks-in" ]; outboundTag = "proxy-vless"; }
										{
											inboundTag = [ "common-in" ];
											domain = [ "geosite:geolocation-cn" ];
											outboundTag = "direct";
										}
										{
											inboundTag = [ "common-in" ];
											domain = [ "geosite:geolocation-!cn" "domain:nya.one" ];
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
									ExecStart = inputs.pkgs.writeShellScript "v2ray-forwarder.start" (stripeTabs
									''
										${ipset} create lo_net hash:net
										${ipset} add lo_net 0.0.0.0/8
										${ipset} add lo_net 10.0.0.0/8
										${ipset} add lo_net 100.64.0.0/10
										${ipset} add lo_net 127.0.0.0/8
										${ipset} add lo_net 169.254.0.0/16
										${ipset} add lo_net 172.16.0.0/12
										${ipset} add lo_net 192.0.0.0/24
										${ipset} add lo_net 192.88.99.0/24
										${ipset} add lo_net 192.168.0.0/16
										${ipset} add lo_net 59.77.0.143
										${ipset} add lo_net 198.18.0.0/15
										${ipset} add lo_net 198.51.100.0/24
										${ipset} add lo_net 203.0.113.0/24
										${ipset} add lo_net 224.0.0.0/4
										${ipset} add lo_net 240.0.0.0/4
										${ipset} add lo_net 255.255.255.255/32

										${ipset} create xmu_net hash:net

										${ipset} create noproxy_net hash:net
										${ipset} add noproxy_net 223.5.5.5

										${ipset} create noproxy_src_net hash:net

										${ipset} create proxy_net hash:net

										${iptables} -t mangle -N v2ray -w
										${iptables} -t mangle -A PREROUTING -j v2ray -w
										${iptables} -t mangle -A v2ray -m set --match-set noproxy_src_net src -j RETURN -w
										${iptables} -t mangle -A v2ray -m set --match-set xmu_net dst -p tcp \
											-j TPROXY --on-port ${xmuPort} --tproxy-mark 1/1 -w
										${iptables} -t mangle -A v2ray -m set --match-set xmu_net dst -p udp \
											-j TPROXY --on-port ${xmuPort} --tproxy-mark 1/1 -w
										${iptables} -t mangle -A v2ray -m set --match-set noproxy_net dst -j RETURN -w
										${iptables} -t mangle -A v2ray -m set --match-set proxy_net dst -p tcp \
											-j TPROXY --on-port ${proxyPort} --tproxy-mark 1/1 -w
										${iptables} -t mangle -A v2ray -m set --match-set proxy_net dst -p udp \
											-j TPROXY --on-port ${proxyPort} --tproxy-mark 1/1 -w
										${iptables} -t mangle -A v2ray -m set --match-set lo_net dst -j RETURN -w
										${iptables} -t mangle -A v2ray -p tcp -j TPROXY --on-port ${autoPort} --tproxy-mark 1/1 -w
										${iptables} -t mangle -A v2ray -p udp -j TPROXY --on-port ${autoPort} --tproxy-mark 1/1 -w

										${iptables} -t mangle -N v2ray_mark -w
										${iptables} -t mangle -A OUTPUT -j v2ray_mark -w
										${iptables} -t mangle -A v2ray_mark -m owner --uid-owner $(id -u v2ray) -j RETURN -w
										${iptables} -t mangle -A v2ray_mark -m set --match-set noproxy_src_net src -j RETURN -w
										${iptables} -t mangle -A v2ray_mark -m set --match-set xmu_net dst -p tcp -j MARK --set-mark 1/1 -w
										${iptables} -t mangle -A v2ray_mark -m set --match-set xmu_net dst -p udp -j MARK --set-mark 1/1 -w
										${iptables} -t mangle -A v2ray_mark -m set --match-set noproxy_net dst -j RETURN -w
										${iptables} -t mangle -A v2ray_mark -m set --match-set proxy_net dst -p tcp \
											-j MARK --set-mark 1/1 -w
										${iptables} -t mangle -A v2ray_mark -m set --match-set proxy_net dst -p udp \
											-j MARK --set-mark 1/1 -w
										${iptables} -t mangle -A v2ray_mark -m set --match-set lo_net dst -j RETURN -w
										${iptables} -t mangle -A v2ray_mark -p tcp -j MARK --set-mark 1/1 -w
										${iptables} -t mangle -A v2ray_mark -p udp -j MARK --set-mark 1/1 -w

										${ip} rule add fwmark 1/1 table 100
										${ip} route add local 0.0.0.0/0 dev lo table 100
									'');
									ExecStop = inputs.pkgs.writeShellScript "v2ray-forwarder.stop" (stripeTabs
									''
										${iptables} -t mangle -F v2ray -w
										${iptables} -t mangle -D PREROUTING -j v2ray -w
										${iptables} -t mangle -X v2ray -w

										${iptables} -t mangle -F v2ray_mark -w
										${iptables} -t mangle -D OUTPUT -j v2ray_mark -w
										${iptables} -t mangle -X v2ray_mark -w

										${ip} rule del fwmark 1/1 table 100
										${ip} route del local 0.0.0.0/0 dev lo table 100

										${ipset} destroy lo_net
										${ipset} destroy xmu_net
										${ipset} destroy noproxy_net
										${ipset} destroy noproxy_src_net
										${ipset} destroy proxy_net
									'');
								};
						};
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
							onlySSL = true;
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
												minClientVer = "1.8.0";
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
						nginx.transparentProxy.map."${services.xrayServer.serverName}" = 4726;
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
									dnsResolver = "8.8.8.8";
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
					nixos.services.nginx.httpProxy.${services.nix-serve.hostname}.upstream = "http://127.0.0.1:5000";
				}
			)
			(mkIf services.smartd.enable { services.smartd.enable = true; })
			(
				mkIf services.wallabag.enable
				{
					virtualisation.oci-containers.containers.wallabag =
					{
						image = "wallabag/wallabag:2.6.2";
						imageFile = inputs.pkgs.dockerTools.pullImage
						{
							imageName = "wallabag/wallabag";
							imageDigest = "sha256:241e5c71f674ee3f383f428e8a10525cbd226d04af58a40ce9363ed47e0f1de9";
							sha256 = "0zflrhgg502w3np7kqmxij8v44y491ar2qbk7qw981fysia5ix09";
							finalImageName = "wallabag/wallabag";
							finalImageTag = "2.6.2";
						};
						ports = [ "127.0.0.1:4398:80/tcp" ];
						extraOptions = [ "--add-host=host.docker.internal:host-gateway" ];
						environmentFiles = [ inputs.config.sops.templates."wallabag/env".path ];
					};
					# systemd.services.docker-wallabag.serviceConfig =
					# {
					# 	User = "wallabag";
					# 	Group = "wallabag";
					# };
					sops =
					{
						templates."wallabag/env".content =
							let
								placeholder = inputs.config.sops.placeholder;
							in stripeTabs
							''
								SYMFONY__ENV__DATABASE_DRIVER=pdo_pgsql
								SYMFONY__ENV__DATABASE_HOST=host.docker.internal
								SYMFONY__ENV__DATABASE_PORT=5432
								SYMFONY__ENV__DATABASE_NAME=wallabag
								SYMFONY__ENV__DATABASE_USER=wallabag
								SYMFONY__ENV__DATABASE_PASSWORD=${placeholder."postgresql/wallabag"}
								SYMFONY__ENV__REDIS_HOST=host.docker.internal
								SYMFONY__ENV__REDIS_PORT=8790
								SYMFONY__ENV__REDIS_PASSWORD=${placeholder."redis/wallabag"}
								SYMFONY__ENV__SERVER_NAME=wallabag.chn.moe
								SYMFONY__ENV__DOMAIN_NAME=https://wallabag.chn.moe
								SYMFONY__ENV__TWOFACTOR_AUTH=false
							'';
							# SYMFONY__ENV__MAILER_DSN=smtp://bot%%40chn.moe@${placeholder."mail/bot-encoded"}:mail.chn.moe
							# SYMFONY__ENV__FROM_EMAIL=bot@chn.moe
							# SYMFONY__ENV__TWOFACTOR_SENDER=bot@chn.moe
						secrets =
						{
							"redis/wallabag".owner = inputs.config.users.users.redis-wallabag.name;
							"postgresql/wallabag" = {};
							"mail/bot-encoded" = {};
						};
					};
					services =
					{
						redis.servers.wallabag =
						{
							enable = true;
							bind = null;
							port = 8790;
							requirePassFile = inputs.config.sops.secrets."redis/wallabag".path;
						};
						postgresql =
						{
							ensureDatabases = [ "wallabag" ];
							ensureUsers =
							[{
								name = "wallabag";
								ensurePermissions."DATABASE \"wallabag\"" = "ALL PRIVILEGES";
							}];
							# ALTER DATABASE db_name OWNER TO new_owner_name
							# sudo docker exec -t wallabag /var/www/wallabag/bin/console wallabag:install --env=prod --no-interaction
						};
					};
					nixos =
					{
						services =
						{
							nginx = { enable = true; httpProxy."wallabag.chn.moe".upstream = "http://127.0.0.1:4398"; };
							postgresql.enable = true;
						};
						virtualization.docker.enable = true;
					};
					# users =
					# {
					# 	users.wallabag = { isSystemUser = true; group = "wallabag"; autoSubUidGidRange = true; };
					# 	groups.wallabag = {};
					# };
				}
			)
		];
}
