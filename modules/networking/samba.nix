inputs:
{
	config =
	{
		# make shares visible for windows 10 clients
		services.samba-wsdd.enable = true;
		# networking.firewall = { allowedTCPPorts = [ 5357 ]; allowedUDPPorts = [ 3702 ]; };
		services.samba =
		{
			enable = true;
			securityType = "user";
			enableWinbindd = true;
			extraConfig =
			''
				workgroup = WORKGROUP
				server string = Samba Server
				server role = standalone server
				hosts allow = 192.168. 127.
				dns proxy = no
			'';
			shares = builtins.listToAttrs (builtins.map
				(config: { name = config.name; value =
				{
					comment = config.comment;
					path = config.path;
					browseable = true;
					writeable = true;
					"create mask" = "664";
					"force create mode" = "644";
					"security mask" = "644";
					"force security mode" = "644";
					"directory mask" = "2755";
					"force directory mode" = "2755";
					"directory security mask" = "2755";
					"force directory security mode" = "2755";
				}; })
				[
					{ name = "media"; comment = "chn media"; path = "/run/media/chn"; }
					{ name = "home"; comment = "chn home"; path = "/home/chn"; }
					{ name = "mnt"; comment = "mnt"; path = "/mnt"; }
					{ name = "share"; comment = "chn share"; path = "/home/chn/share"; }
				]);
		};
	};
}
