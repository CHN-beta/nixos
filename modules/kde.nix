{ pkgs, ... }@inputs:
{
	config =
	{
		services.xserver =
		{
			enable = true;
			displayManager.sddm.enable = true;
			desktopManager.plasma5.enable = true;
		};
		environment =
		{
			sessionVariables."GTK_USE_PORTAL" = "1";
			systemPackages = [ inputs.pkgs.libsForQt5.qtstyleplugin-kvantum ];
		};
		xdg.portal.extraPortals = with inputs.pkgs; [ xdg-desktop-portal-gtk xdg-desktop-portal-wlr ];
		programs.xwayland.enable = true;
		programs.kdeconnect.enable = true;
	};
}
