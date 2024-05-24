inputs:
{
  config = inputs.lib.mkIf (builtins.elem "desktop-extra" inputs.config.nixos.packages._packageSets)
  {
    nixos =
    {
      packages = with inputs.pkgs;
      {
        _packages =
        [
          # system management
          btrfs-assistant snapper-gui libsForQt5.qtstyleplugin-kvantum ventoy-full cpu-x # etcher
          # password and key management
          yubikey-manager yubikey-manager-qt yubikey-personalization yubikey-personalization-gui bitwarden
          # download
          qbittorrent nur-xddxdd.baidupcs-go wgetpaste
          # development
          scrcpy weston cage openbox krita
          # media
          spotify yesplaymusic simplescreenrecorder imagemagick gimp netease-cloud-music-gtk vlc obs-studio
          waifu2x-converter-cpp inkscape blender
          # editor
          typora
          # themes
          orchis-theme plasma-overdose-kde-theme materia-kde-theme graphite-kde-theme arc-kde-theme materia-theme
          # news
          fluent-reader
          # nix tools
          deploy-rs.deploy-rs nixpkgs-fmt appimage-run nixd nix-serve node2nix nix-prefetch-github prefetch-npm-deps
          nix-prefetch-docker
          # instant messager
          element-desktop telegram-desktop discord fluffychat zoom-us signal-desktop slack nur-linyinfeng.wemeet
          # browser
          google-chrome
          # office
          crow-translate zotero pandoc ydict libreoffice-qt texstudio poppler_utils pdftk gnuplot pdfchain hdfview
          texliveFull
          # math, physics and chemistry
          octaveFull root ovito localPackages.vesta localPackages.vaspkit localPackages.v-sim
        ]
        ++ (builtins.filter (p: !(p.meta.broken or false))
          (builtins.filter inputs.lib.isDerivation (builtins.attrValues kdePackages.kdeGear)));
      };
    };
    programs.kdeconnect.enable = true;
  };
}
