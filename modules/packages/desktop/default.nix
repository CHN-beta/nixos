inputs:
{
  config = inputs.lib.mkIf (builtins.elem "desktop" inputs.config.nixos.packages._packageSets)
  {
    nixos =
    {
      packages._packages = with inputs.pkgs;
      [
        # system management
        gparted wayland-utils clinfo glxinfo vulkan-tools dracut
        (
          writeShellScriptBin "xclip"
          ''
            #!${bash}/bin/bash
            if [ "$XDG_SESSION_TYPE" = "x11" ]; then
              exec ${xclip}/bin/xclip -sel clip "$@"
            else
              exec ${wl-clipboard-x11}/bin/xclip "$@"
            fi
          ''
        )
        # color management
        argyllcms xcalib
        # networking
        remmina putty mtr-gui
        # media
        mpv nomacs
        # themes
        localPackages.win11os-kde localPackages.fluent-kde localPackages.blurred-wallpaper
        localPackages.slate utterly-nord-plasma utterly-round-plasma-style catppuccin catppuccin-sddm
        catppuccin-cursors catppuccinifier-gui catppuccinifier-cli catppuccin-plymouth
        (catppuccin-kde.override { flavour = [ "latte" ]; })
        (catppuccin-gtk.override { variant = "latte"; })
        (tela-circle-icon-theme.override { allColorVariants = true; })
        whitesur-kde whitesur-gtk-theme
        # terminal
        warp-terminal
        # development
        adb-sync
        # desktop sharing
        rustdesk-flutter
      ];
    };
    programs =
    {
      adb.enable = true;
      wireshark = { enable = true; package = inputs.pkgs.wireshark; };
      yubikey-touch-detector.enable = true;
    };
    nixpkgs.overlays = [(final: prev:
    {
      telegram-desktop = prev.telegram-desktop.overrideAttrs (attrs:
      {
        patches = (if (attrs ? patches) then attrs.patches else []) ++ [ ./telegram.patch ];
      });
    })];
    services.pcscd.enable = true;
  };
}
