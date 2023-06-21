inputs:
{
	config =
	{
		services =
		{
			dnsmasq =
			{
				enable = true;
				settings =
				{
					no-poll = true;
					server = [ "127.0.0.1#10853" ];
					listen-address = "127.0.0.1";
					bind-interfaces = true;
					ipset =
					[
						"/developer.download.nvidia.com/noproxy_net"
						"/yuanshen.com/noproxy_net"
						"/zoom.us/noproxy_net"
					];	
				};
			};
			xray = { enable = true; settingsFile = inputs.config.sops.secrets."xray.json".path; };
			v2ray-forwarder = { enable = true; proxyPort = 10880; xmuPort = 10881; };
		};
		sops.secrets."xray.json" =
			{ mode = "0440"; owner = "v2ray"; group = "v2ray"; restartUnits = [ "xray.service" ]; };
		systemd.services.xray.serviceConfig =
		{
			DynamicUser = inputs.lib.mkForce false;
			User = "v2ray";
			Group = "v2ray";
			CapabilityBoundingSet = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
			AmbientCapabilities = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
			LimitNPROC = 10000;
			LimitNOFILE = 1000000;
		};
		users = { users.v2ray = { isSystemUser = true; group = "v2ray"; }; groups.v2ray = {}; };
		boot.kernel.sysctl =
		{
			"net.ipv4.conf.all.route_localnet" = true;
			"net.ipv4.conf.default.route_localnet" = true;
			"net.ipv4.conf.all.accept_local" = true;
			"net.ipv4.conf.default.accept_local" = true;
			"net.ipv4.ip_forward" = true;
			"net.ipv4.ip_nonlocal_bind" = true;
			"net.bridge.bridge-nf-call-iptables" = false;
			"net.bridge.bridge-nf-call-ip6tables" = false;
			"net.bridge.bridge-nf-call-arptables" = false;
		};
		environment.etc."resolv.conf".text = "nameserver 127.0.0.1";
		networking.firewall.trustedInterfaces = [ "docker0" "virbr0" ];
	};
}
