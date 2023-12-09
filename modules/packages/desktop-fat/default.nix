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
            etcher btrfs-assistant snapper-gui libsForQt5.qtstyleplugin-kvantum
            # password and key management
            yubikey-manager yubikey-manager-qt yubikey-personalization yubikey-personalization-gui bitwarden
            # download
            qbittorrent nur-xddxdd.baidupcs-go wgetpaste
            # development
            scrcpy weston cage openbox krita
            # media
            spotify yesplaymusic simplescreenrecorder imagemagick gimp netease-cloud-music-gtk vlc
            # editor
            localPackages.typora
            # themes
            orchis-theme plasma-overdose-kde-theme materia-kde-theme graphite-kde-theme arc-kde-theme materia-theme
            # news
            fluent-reader
            # nix tools
            deploy-rs.deploy-rs nixpkgs-fmt
            # instant messager
            element-desktop telegram-desktop discord # native
            # browser
            google-chrome
            # office
            crow-translate zotero pandoc ydict
          ] ++ (with inputs.lib; filter isDerivation (attrValues plasma5Packages.kdeGear));
        };
      };
      programs = { steam.enable = true; kdeconnect.enable = true; };
    };
}
