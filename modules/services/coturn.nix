inputs:
{
	options.nixos.services.coturn = let inherit (inputs.lib) mkOption types; in
	{
		enable = mkOption { type = types.bool; default = false; };
		port = mkOption { type = types.ints.unsigned; default = 5349; };
		hostname = mkOption { type = types.str; default = "coturn.chn.moe"; };
	};
	config =
		let
			inherit (inputs.config.nixos.services) coturn;
			inherit (inputs.lib) mkIf;
		in mkIf coturn.enable
			{
				services.coturn =
					let
						keydir = inputs.config.security.acme.certs.${coturn.hostname}.directory;
					in
					{
						enable = true;
						use-auth-secret = true;
						static-auth-secret-file = inputs.config.sops.secrets."coturn/auth-secret".path;
						realm = coturn.hostname;
						cert = "${keydir}/full.pem";
						pkey = "${keydir}/key.pem";
						tls-listening-port = coturn.port;
						no-tcp = true;
						no-udp = true;
						no-cli = true;
					};
				sops.secrets."coturn/auth-secret".owner = inputs.config.systemd.services.coturn.serviceConfig.User;
				nixos.services.acme = { enable = true; certs = [ coturn.hostname ]; };
				security.acme.certs.${coturn.hostname}.group = inputs.config.systemd.services.coturn.serviceConfig.Group;
				networking.firewall.allowedUDPPorts = [ coturn.port ];
				networking.firewall.allowedUDPPortRanges = with inputs.config.services.coturn;
					[ { from = min-port; to = max-port; } ];
			};
}
