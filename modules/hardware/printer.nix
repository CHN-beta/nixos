{ pkgs, ... }@inputs:
{
	config.services =
	{
		printing = { enable = true; drivers = [ pkgs.cnijfilter2 ]; };
		avahi = { enable = true; nssmdns = true; openFirewall = true; };
	};
}
