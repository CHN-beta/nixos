inputs:
{
  imports = inputs.localLib.mkModules [ ./vscode.nix ];
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
          gparted wl-clipboard-x11 kio-fuse wayland-utils clinfo glxinfo vulkan-tools dracut
          # color management
          argyllcms xcalib
          # networking
          remmina putty mtr-gui
          # media
          mpv nomacs
          # themes
          tela-circle-icon-theme
        ];
        users.sharedModules =
        [{
          config.home.file.".config/baloofilerc".text =
          ''
            [Basic Settings]
            Indexing-Enabled=false
          '';
        }];
      };
      programs =
      {
        adb.enable = true;
        wireshark = { enable = true; package = inputs.pkgs.wireshark; };
        firefox = { enable = true; languagePacks = [ "zh-CN" "en-US" ]; };
        vim.package = inputs.pkgs.vim-full;
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

