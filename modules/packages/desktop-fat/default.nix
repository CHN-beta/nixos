inputs:
{
  imports = inputs.localLib.mkModules
  [
    ./chromium.nix
  ];
  config =
    let
      inherit (inputs.lib) mkIf;
    in mkIf (builtins.elem "desktop-fat" inputs.config.nixos.packages._packageSets)
    {
      nixos =
      {
        packages = with inputs.pkgs;
        {
          _packages =
          [
            # system management
            etcher btrfs-assistant
            # password and key management
            yubikey-manager yubikey-manager-qt yubikey-personalization yubikey-personalization-gui electrum jabref
            # download
            qbittorrent nur-xddxdd.baidupcs-go wgetpaste
            # development
            scrcpy weston cage openbox krita
            # media
            spotify yesplaymusic simplescreenrecorder imagemagick gimp netease-cloud-music-gtk vlc
            # editor
            localPackages.typora hdfview
            # themes
            orchis-theme plasma-overdose-kde-theme materia-kde-theme graphite-kde-theme arc-kde-theme materia-theme
            # news
            fluent-reader rssguard newsflash newsboat
            # nix tools
            deploy-rs.deploy-rs nixpkgs-fmt
            # instant messager
            element-desktop telegram-desktop discord inputs.config.nur.repos.linyinfeng.wemeet # native
            cinny-desktop # nur-xddxdd.wine-wechat thunder
            # browser
            google-chrome microsoft-edge
          ] ++ (with inputs.lib; filter isDerivation (attrValues plasma5Packages.kdeGear));
        };
        users.sharedModules =
        [{
          config.programs =
          {
            obs-studio =
            {
              enable = true;
              plugins = with inputs.pkgs.obs-studio-plugins;
                [ wlrobs obs-vaapi obs-nvfbc droidcam-obs obs-vkcapture ];
            };
            doom-emacs = { enable = true; doomPrivateDir = ./doom.d; };
          };
        }];
      };
      programs = { steam.enable = true; kdeconnect.enable = true; };
    };
}
