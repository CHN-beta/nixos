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
          gparted snapper-gui libsForQt5.qtstyleplugin-kvantum wl-clipboard-x11 kio-fuse wl-mirror
          wayland-utils clinfo glxinfo vulkan-tools dracut                
          # networking
          remmina putty mtr-gui
          # password and key management
          bitwarden
          # office
          crow-translate zotero pandoc ydict logseq
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

