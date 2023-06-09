{ hostname }: { pkgs, ... }@inputs:
{
	config =
	{
		nixpkgs.hostPlatform = "x86_64-linux";
		nix.settings.experimental-features = [ "nix-command" "flakes" ];
		networking.hostName = hostname;
		time.timeZone = "Asia/Shanghai";
		system.stateVersion = "22.11";
		nixpkgs.config.allowUnfree = true;


		programs.firejail.enable = true;
		hardware.xone.enable = true;
		hardware.xpadneo.enable = true;
		hardware.bluetooth.enable = true;
		services.xserver.synaptics.enable = false;
		services.xserver.libinput.enable = true;
		virtualisation.libvirtd.enable = true;

		nixpkgs.config.packageOverrides = pkgs: rec {
			wpa_supplicant = pkgs.wpa_supplicant.overrideAttrs (attrs: {
				patches = attrs.patches ++ [ ../../patches/xmunet.patch ];
			});
		};

		environment.sessionVariables."GTK_USE_PORTAL" = "1";
		xdg.portal.extraPortals = with inputs.pkgs; [ xdg-desktop-portal-gtk xdg-desktop-portal-wlr ];
		virtualisation.spiceUSBRedirection.enable = true;
		networking.resolvconf.enable = false;
		environment.etc."resolv.conf".text =
		''
			nameserver 127.0.0.1
		'';
		programs.xwayland.enable = true;
	};
}
