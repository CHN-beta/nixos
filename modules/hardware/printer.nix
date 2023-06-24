inputs:
{
	config.services =
	{
		printing = { enable = true; drivers = [ inputs.pkgs.cnijfilter2 ]; };
		avahi = { enable = true; nssmdns = true; openFirewall = true; };
	};
}
