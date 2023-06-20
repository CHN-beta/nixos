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
			extraConfig =
			''
				workgroup = WORKGROUP
				server string = Samba Server
				server role = standalone server
				hosts allow = 192.168. 127.
				dns proxy = no
			'';
			shares =
			{
				media =
				{
					comment = "chn media";
					path = "/run/media/chn";
					browseable = true;
					writeable = true;
				};
				home =
				{
					comment = "chn home";
					path = "/home/chn";
					browseable = true;
					writeable = true;
				};
				mnt =
				{
					comment = "mnt";
					path = "/mnt";
					browseable = true;
					writeable = true;
				};
				share =
				{
					comment = "chn share";
					path = "/home/chn/share";
					browseable = true;
					writeable = true;
				};
			};
		};
	};
}
