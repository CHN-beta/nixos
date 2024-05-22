inputs:
{
  config = inputs.lib.mkIf (builtins.elem "desktop" inputs.config.nixos.packages._packageSets)
  {
    nixos =
    {
      packages._packages = with inputs.pkgs;
      [
        # system management
        gparted kio-fuse wayland-utils clinfo glxinfo vulkan-tools dracut
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
        tela-circle-icon-theme localPackages.win11os-kde localPackages.fluent-kde localPackages.blurred-wallpaper
        localPackages.slate utterly-nord-plasma
        # terminal
        warp-terminal
        # development
        adb-sync
        # virtual keyboard
        localPackages.kylin-virtual-keyboard
      ];
    };
    programs =
    {
      adb.enable = true;
      wireshark = { enable = true; package = inputs.pkgs.wireshark; };
      vim.package = inputs.pkgs.vim-full;
      yubikey-touch-detector.enable = true;
    };
    nixpkgs.config.packageOverrides = pkgs: 
    {
      telegram-desktop = pkgs.telegram-desktop.overrideAttrs (attrs:
      {
        patches = (if (attrs ? patches) then attrs.patches else []) ++ [ ./telegram.patch ];
      });
    };
    services.pcscd.enable = true;
  };
}

