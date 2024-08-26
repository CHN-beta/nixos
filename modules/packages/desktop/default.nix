inputs:
{
  options.nixos.packages.desktop = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = if inputs.config.nixos.system.gui.enable then {} else null;
  };
  config = let inherit (inputs.config.nixos.packages) desktop; in inputs.lib.mkIf (desktop != null)
  {
    nixos =
    {
      packages.packages =
      {
        _packages = with inputs.pkgs;
        [
          # system management
          # TODO: module should add yubikey-touch-detector into path
          gparted wayland-utils clinfo glxinfo vulkan-tools dracut yubikey-touch-detector btrfs-assistant snapper-gui
          kdePackages.qtstyleplugin-kvantum ventoy-full cpu-x inputs.pkgs."pkgs-23.11".etcher wl-mirror
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
          mpv nomacs spotify yesplaymusic simplescreenrecorder imagemagick gimp netease-cloud-music-gtk vlc obs-studio
          waifu2x-converter-cpp inkscape blender whalebird paraview
          # themes
          catppuccin catppuccin-sddm catppuccin-cursors catppuccinifier-gui catppuccinifier-cli catppuccin-plymouth
          (catppuccin-kde.override { flavour = [ "latte" ]; }) (catppuccin-kvantum.override { variant = "latte"; })
          localPackages.slate localPackages.blurred-wallpaper tela-circle-icon-theme
          # terminal
          warp-terminal
          # development
          adb-sync scrcpy weston cage openbox krita jetbrains.clion android-studio dbeaver-bin cling fprettify
          aircrack-ng
          # desktop sharing
          rustdesk-flutter
          # password and key management
          yubikey-manager yubikey-manager-qt yubikey-personalization yubikey-personalization-gui bitwarden electrum
          jabref
          john crunch hashcat
          # download
          qbittorrent nur-xddxdd.baidupcs-go wgetpaste onedrive onedrivegui rclone
          # editor
          typora appflowy notion-app-enhanced joplin-desktop standardnotes logseq
          # news
          fluent-reader rssguard newsflash newsboat
          # nix tools
          nixpkgs-fmt appimage-run nixd nix-serve node2nix nix-prefetch-github prefetch-npm-deps nix-prefetch-docker
          nix-template nil pnpm-lock-export bundix
          # instant messager
          element-desktop telegram-desktop discord fluffychat zoom-us signal-desktop slack nur-linyinfeng.wemeet
          cinny-desktop nheko # qq nur-xddxdd.wechat-uos
          # browser
          google-chrome tor-browser microsoft-edge
          # office
          crow-translate zotero pandoc ydict libreoffice-qt texstudio poppler_utils pdftk gnuplot pdfchain hdfview
          davinci-resolve
          texliveFull
          # math, physics and chemistry
          octaveFull root ovito localPackages.vesta localPackages.vaspkit localPackages.v-sim
          (mathematica.overrideAttrs (prev: { postInstall = prev.postInstall or "" + "ln -s ${src} $out/src"; }))
          (quantum-espresso.override { stdenv = gcc14Stdenv; gfortran = gfortran14; }) jmol mpi
          # virtualization
          # TODO: broken on python 3.12: playonlinux
          wineWowPackages.stagingFull virt-viewer bottles genymotion
          # media
          nur-xddxdd.svp
          # for kdenlive auto subtitle
          openai-whisper
        ]
          ++ (builtins.filter (p: !((p.meta.broken or false) || (builtins.elem p.pname or null [ "falkon" "kalzium" ])))
            (builtins.filter inputs.lib.isDerivation (builtins.attrValues kdePackages.kdeGear)));
          # TODO: fix it
          # ++ inputs.lib.optional (inputs.config.nixos.system.nixpkgs.march != null) localPackages.mumax;
        _pythonPackages = [(pythonPackages: with pythonPackages;
        [
          phonopy scipy scikit-learn jupyterlab autograd # localPackages.pix2tex
          # TODO: broken on python 3.12: tensorflow keras
        ])];
      };
      user.sharedModules =
      [{
        config.programs =
        {
          plasma = 
          {
            enable = true;
            configFile =
            {
              plasma-localerc = { Formats.LANG.value = "en_US.UTF-8"; Translations.LANGUAGE.value = "zh_CN"; };
              baloofilerc."Basic Settings".Indexing-Enabled.value = false;
            };
            powerdevil =
              let config =
              {
                autoSuspend.action = "nothing";
                dimDisplay.enable = false;
                powerButtonAction = "turnOffScreen";
                turnOffDisplay.idleTimeout = "never";
                whenLaptopLidClosed = "turnOffScreen";
              };
              in { AC = config; battery = config; lowBattery = config; };
          };
          obs-studio =
          {
            enable = true;
            plugins = with inputs.pkgs.obs-studio-plugins; [ wlrobs obs-vaapi obs-nvfbc droidcam-obs obs-vkcapture ];
          };
        };
      }];
    };
    programs =
    {
      adb.enable = true;
      wireshark = { enable = true; package = inputs.pkgs.wireshark; };
      yubikey-touch-detector.enable = true;
      kdeconnect.enable = true;
      anime-game-launcher = { enable = true; package = inputs.pkgs.anime-game-launcher; };
      honkers-railway-launcher = { enable = true; package = inputs.pkgs.honkers-railway-launcher; };
      sleepy-launcher = { enable = true; package = inputs.pkgs.sleepy-launcher; };
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
