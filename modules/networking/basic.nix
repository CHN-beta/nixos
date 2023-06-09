inputs:
{
	config.networking.networkmanager.enable = true;
	config.services.dnsmasq =
	{
		enable = true;
		settings = {
			no-poll = true;
			server = [ "127.0.0.1#10853" ];
			listen-address = "127.0.0.1";
			bind-interfaces = true;
			address = [
				"/mirism.one/216.24.188.24"
				"/beta.mirism.one/216.24.188.24"
				"/ng01.mirism.one/216.24.188.24"
				"/debug.mirism.one/127.0.0.1"
			];
			ipset = [
				"/developer.download.nvidia.com/noproxy_net"
				"/yuanshen.com/noproxy_net"
				"/zoom.us/noproxy_net"
			];	
		};
	};
	config.services.xray = { enable = true; settingsFile = inputs.config.sops.secrets."xray.json".path; };
	config.sops.secrets."xray.json" =
		{ mode = "0440"; owner = "v2ray"; group = "v2ray"; restartUnits = [ "xray.service" ]; };
	config.systemd.services.xray.serviceConfig =
	{
		DynamicUser = inputs.lib.mkForce false;
		User = "v2ray";
		Group = "v2ray";
		CapabilityBoundingSet = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
		AmbientCapabilities = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
	};
	config.users.users.v2ray = { isSystemUser = true; group = "v2ray"; };
	config.users.groups.v2ray = {};
	config.services.v2ray-forwarder = { enable = true; proxyPort = 10880; xmuPort = 10881; };
	config.boot.kernel.sysctl =
	{
		"net.ipv4.conf.all.route_localnet" = true;
		"net.ipv4.conf.default.route_localnet" = true;
		"net.ipv4.conf.all.accept_local" = true;
		"net.ipv4.conf.default.accept_local" = true;
		"net.ipv4.ip_forward" = true;
		"net.ipv4.ip_nonlocal_bind" = true;
	};
}
