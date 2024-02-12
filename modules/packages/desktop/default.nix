inputs:
{
  imports = inputs.localLib.mkModules [ ./vscode.nix ./firefox.nix ];
  config =
    let
      inherit (inputs.lib) mkIf;
    in mkIf (builtins.elem "desktop" inputs.config.nixos.packages._packageSets)
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
                exec ${xclip}/bin/xclip "$@"
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
        ];
        users.sharedModules =
        [(homeInputs: {
          config.home.file = mkIf (!homeInputs.config.programs.plasma.enable)
          {
            ".config/baloofilerc".text =
            ''
              [Basic Settings]
              Indexing-Enabled=false
            '';
          };
        })];
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

